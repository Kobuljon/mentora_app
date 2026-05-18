import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_litert_lm/flutter_litert_lm.dart';
import '../../../core/services/cloud_ai_service.dart';
import '../../../core/services/optimized_litert_engine_factory.dart';
import '../../onboarding/services/model_download_service.dart';
import '../../settings/providers/settings_provider.dart';

class AiStudyService {
  AiStudyService(this._settings);

  final AppSettings _settings;
  LiteLmEngine? _engine;

  Future<void> initialize({String? modelPath}) async {
    if (_useCloudBackend) return;
    if (_engine != null) return;

    final resolvedModelPath =
        modelPath ?? await ModelDownloadService.instance.getReadyModelPath();

    _engine = await OptimizedLiteRtEngineFactory.create(
      modelPath: resolvedModelPath,
      enableVision: false,
    );
  }

  Future<List<String>> generateQuestions(String textContext, int count) async {
    final candidateCount = _candidateQuestionCount(count);
    final systemInstruction = _buildQuestionGenerationInstruction(
      requestedCount: count,
      candidateCount: candidateCount,
    );
    final prompt = _buildQuestionGenerationPrompt(
      textContext: textContext,
      requestedCount: count,
      candidateCount: candidateCount,
    );

    if (_useCloudBackend) {
      final responseText = await CloudAiService(
        _settings,
      ).generate(systemInstruction: systemInstruction, prompt: prompt);
      return _parseQuestionCandidates(responseText, textContext, count);
    }

    if (_engine == null) throw StateError('Not initialized');

    final conversation = await _engine!.createConversation(
      LiteLmConversationConfig(
        systemInstruction: systemInstruction,
        automaticToolCalling: false,
      ),
    );

    try {
      var responseText = '';
      await for (final chunk in conversation.sendMessageStream(prompt)) {
        responseText += chunk.text;
      }
      return _parseQuestionCandidates(responseText, textContext, count);
    } finally {
      await conversation.dispose();
    }
  }

  String _buildQuestionGenerationInstruction({
    required int requestedCount,
    required int candidateCount,
  }) {
    final quizModeGuidance = _settings.languageLearnerModeEnabled
        ? '''
Quiz mode: LANGUAGE LEARNER.
Prioritize questions that help someone learn English from this material:
- vocabulary meaning in context
- useful grammar patterns from real sentences in the text
- pronunciation, spelling, word form, or collocation only when the selected word/phrase is important in the material
- comprehension questions when they help confirm the learner understood the language in context

Good language-learning questions should still be grounded in the study text. Do not ask about a random word just because it appears once.
'''
        : '''
Quiz mode: REGULAR LEARNER.
Prioritize normal reading-comprehension questions:
- events, facts, claims, causes, effects, motivations, sequence, comparison, and inference
- key vocabulary only when the word is essential to understanding the material

Do not make the quiz mainly about grammar, pronunciation, spelling, or isolated word analysis.
''';

    return '''
You are a thoughtful middle-school English teacher creating a reading-comprehension quiz.

Use ONLY the provided study text as the source. Ignore source labels, chunk labels, page labels, app instructions, JSON instructions, and formatting markers.

Generate exactly $candidateCount candidate questions. The app will keep the strongest $requestedCount.

$quizModeGuidance

Good quiz questions MUST:
- test comprehension of events, facts, claims, causes, effects, motivations, sequence, comparison, or inference from the study text
- test important vocabulary from the study text when the word matters for understanding the material
- be answerable from specific evidence in the study text
- ask about meaningful ideas from the material, not random words
- use clear language for 12-16 year old learners
- be open-ended and answerable in 1-3 sentences

Never generate:
- questions about the function, role, or grammar job of a random isolated word or phrase
- questions like "What is the function of the word X?" or "What role does the phrase X play?"
- questions about "instruction", "JSON", "source", "chunk", "page number", or app/system prompt text
- vocabulary questions about metadata, labels, formatting, or app/system instructions
- generic questions such as "What is the main idea of the text?" unless they name a specific topic from the text
- yes/no questions, true/false questions, multiple-choice questions, fill-in-the-blank questions, or grammar drills

=== REQUIRED OUTPUT FORMAT ===
Return ONLY a single JSON array of objects, wrapped exactly between the literal markers [[JSON_START]] and [[JSON_END]].
Rules (all are MANDATORY):
1. No prose, no commentary, no Markdown, no code fences before, between, or after the markers.
2. Use ONLY straight ASCII double quotes (") for keys and string values. Never use smart quotes.
3. Each object must have exactly these string keys: "question", "answerFocus", "evidence".
4. "question" is the student-facing question. It must end with a question mark.
5. "answerFocus" is a short phrase describing the expected answer.
6. "evidence" is a short source phrase that proves the question came from the study text.
7. No raw newlines, tabs, or control characters inside strings.
8. Escape any internal double quotes as \\".
9. No trailing commas before } or ].

Exact shape:
[[JSON_START]][{"question":"Why did the character make that choice?","answerFocus":"reason for the choice","evidence":"short phrase from the study text"}][[JSON_END]]
''';
  }

  String _buildQuestionGenerationPrompt({
    required String textContext,
    required int requestedCount,
    required int candidateCount,
  }) {
    return '''
Create $candidateCount strong candidate quiz questions. I need $requestedCount final questions after quality filtering.

Current quiz mode: ${_settings.languageLearnerModeEnabled ? 'language learner' : 'regular learner'}.

Study text starts below. Treat bracketed source/page/chunk labels as metadata, not quiz content.

[[STUDY_TEXT_START]]
$textContext
[[STUDY_TEXT_END]]
''';
  }

  int _candidateQuestionCount(int requestedCount) {
    return math.min(30, math.max(requestedCount + 3, requestedCount * 2));
  }

  List<String> _parseQuestionCandidates(
    String responseText,
    String sourceText,
    int requestedCount,
  ) {
    final decoded = _parseJsonList(responseText);
    final sourceTokens = _contentTokens(sourceText).toSet();
    final questions = <String>[];
    final seen = <String>{};

    for (final item in decoded) {
      final question = _questionTextFromCandidate(item);
      if (question == null) continue;

      final normalized = _normalizeQuestion(question);
      if (isLowQualityGeneratedQuestion(normalized)) continue;
      if (!_isGroundedInSource(normalized, sourceTokens)) continue;

      final fingerprint = normalized
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .trim();
      if (!seen.add(fingerprint)) continue;

      questions.add(normalized);
      if (questions.length == requestedCount) break;
    }

    if (questions.isEmpty) {
      throw FormatException(
        'Generated questions were not usable comprehension questions.',
      );
    }
    return questions;
  }

  String? _questionTextFromCandidate(Object? item) {
    if (item is String) return item;
    if (item is Map) {
      final question = item['question'] ?? item['Question'];
      if (question != null) return question.toString();
    }
    return null;
  }

  String _normalizeQuestion(String question) {
    final normalized = question
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'''^[\s"']+|[\s"']+$'''), '')
        .trim();
    if (normalized.endsWith('?')) return normalized;
    return '$normalized?';
  }

  @visibleForTesting
  static bool isLowQualityGeneratedQuestion(String question) {
    final q = question.toLowerCase();
    final wordCount = RegExp(r'\b[a-z]+\b').allMatches(q).length;
    if (wordCount < 5) return true;

    final bannedPatterns = [
      RegExp(
        r'\b(function|role|part of speech|grammatical role)\b.*\b(word|phrase|term)\b',
      ),
      RegExp(r'\bwhich word\b|\bwhat word\b'),
      RegExp(
        r'\b(fill in the blank|true or false|multiple choice|yes or no)\b',
      ),
      RegExp(
        r'\b(instruction|json|system prompt|output format|json_start|json_end|chunk label|source label)\b',
      ),
      RegExp(r'\b(page number|chunk number)\b'),
      RegExp(
        r'\bwhat is the (main idea|purpose|topic|summary) of (the )?(text|passage|article|story)\b',
      ),
    ];

    return bannedPatterns.any((pattern) => pattern.hasMatch(q));
  }

  bool _isGroundedInSource(String question, Set<String> sourceTokens) {
    final questionTokens = _contentTokens(question).toSet()
      ..removeAll(_questionOnlyTokens);
    if (questionTokens.isEmpty) return false;

    final overlap = questionTokens.where(sourceTokens.contains).length;
    return overlap >= math.min(2, questionTokens.length);
  }

  static const _questionOnlyTokens = {
    'what',
    'when',
    'where',
    'why',
    'how',
    'which',
    'who',
    'whom',
    'whose',
    'describe',
    'explain',
    'compare',
    'identify',
    'according',
    'text',
    'passage',
    'story',
    'article',
  };

  Iterable<String> _contentTokens(String text) {
    const stopWords = {
      'about',
      'after',
      'again',
      'also',
      'because',
      'before',
      'being',
      'could',
      'from',
      'have',
      'into',
      'more',
      'most',
      'only',
      'over',
      'that',
      'their',
      'them',
      'then',
      'there',
      'these',
      'they',
      'this',
      'those',
      'through',
      'under',
      'were',
      'what',
      'when',
      'where',
      'which',
      'while',
      'with',
      'would',
      'your',
      'source',
      'page',
      'chunk',
      'training',
      'data',
    };

    return RegExp(r'[a-zA-Z][a-zA-Z-]{2,}')
        .allMatches(text.toLowerCase())
        .map((match) => match.group(0)!.replaceAll('-', ''))
        .where((token) => token.length >= 4)
        .where((token) => !stopWords.contains(token));
  }

  Future<Map<String, dynamic>> evaluateAnswers(
    List<String> questions,
    List<String> answers,
    bool checkGrammar,
  ) async {
    final systemInstruction =
        "You are a helpful English teacher evaluating a student's answers.\n\n"
        "=== REQUIRED OUTPUT FORMAT ===\n"
        "Return ONLY a single JSON object, wrapped exactly between the literal markers [[JSON_START]] and [[JSON_END]].\n"
        "Rules (all are MANDATORY):\n"
        "1. No prose, no commentary, no Markdown, no code fences before, between, or after the markers.\n"
        "2. Use ONLY straight ASCII double quotes (\") for keys and string values. Never use smart quotes.\n"
        "3. Inside any string value: NO raw newlines, tabs, or control characters. Write feedback as a single line; if you need a break use the escape sequence \\n.\n"
        "4. Escape any internal double quote as \\\".\n"
        "5. No trailing commas before } or ].\n"
        "6. Produce exactly one evaluation entry per question, in order, with questionIndex starting at 0.\n"
        "7. isCorrect must be a JSON boolean (true or false), not a string.\n\n"
        "Exact schema:\n"
        '{"evaluations":[{"questionIndex":0,"isCorrect":true,"feedback":"short single-line feedback","grammarFeedback":"optional single-line grammar note or empty string"}],"overallFeedback":"short single-line summary"}\n\n'
        "Wrap the whole object exactly like: [[JSON_START]]{...}[[JSON_END]]";

    final content = StringBuffer();
    for (var i = 0; i < questions.length; i++) {
      content.writeln('Q$i: ${questions[i]}');
      content.writeln('A$i: ${answers[i]}\n');
    }
    content.writeln('Please evaluate these answers.');
    if (checkGrammar) {
      content.writeln('Include strict grammar correction feedback if needed.');
    }

    if (_useCloudBackend) {
      final responseText = await CloudAiService(_settings).generate(
        systemInstruction: systemInstruction,
        prompt: content.toString(),
      );
      return _parseJsonObject(responseText);
    }

    if (_engine == null) throw StateError('Not initialized');

    final conversation = await _engine!.createConversation(
      LiteLmConversationConfig(
        systemInstruction: systemInstruction,
        automaticToolCalling: false,
      ),
    );

    var responseText = '';
    await for (final chunk in conversation.sendMessageStream(
      content.toString(),
    )) {
      responseText += chunk.text;
    }

    await conversation.dispose();

    return _parseJsonObject(responseText);
  }

  List<Object?> _parseJsonList(String text) {
    final candidate = _extractJsonCandidate(
      text,
      openChar: '[',
      closeChar: ']',
    );
    final attempts = _sanitizeAttempts(candidate);
    for (final attempt in attempts) {
      try {
        final decoded = jsonDecode(attempt);
        if (decoded is List) {
          return decoded.cast<Object?>();
        }
      } catch (_) {
        // try next attempt
      }
    }
    // Last-resort fallback: pull any double-quoted strings out of the candidate.
    final exp = RegExp(r'"((?:[^"\\]|\\.)*)"');
    final matches = exp.allMatches(candidate);
    final list = matches.map((m) => _unescape(m.group(1)!)).toList();
    if (list.isNotEmpty) return list;
    throw FormatException(
      'Failed to parse AI response as JSON array.\nResponse was: $text',
    );
  }

  Map<String, dynamic> _parseJsonObject(String text) {
    final candidate = _extractJsonCandidate(
      text,
      openChar: '{',
      closeChar: '}',
    );
    final attempts = _sanitizeAttempts(candidate);
    Object? lastError;
    for (final attempt in attempts) {
      try {
        final decoded = jsonDecode(attempt);
        if (decoded is Map) {
          return decoded.cast<String, dynamic>();
        }
      } catch (e) {
        lastError = e;
      }
    }
    throw FormatException(
      'Failed to parse AI response as JSON object: $lastError\nResponse was: $text',
    );
  }

  /// Extracts the most likely JSON payload from a model response. Strips
  /// `[[JSON_START]]`/`[[JSON_END]]` markers and Markdown code fences when
  /// present, otherwise returns the largest brace/bracket-balanced span.
  String _extractJsonCandidate(
    String text, {
    required String openChar,
    required String closeChar,
  }) {
    var working = text;

    // Prefer the explicit markers if both are present and well-ordered.
    final startMarker = working.indexOf('[[JSON_START]]');
    final endMarker = working.lastIndexOf('[[JSON_END]]');
    if (startMarker != -1 && endMarker != -1 && endMarker > startMarker) {
      working = working
          .substring(startMarker + '[[JSON_START]]'.length, endMarker)
          .trim();
    }

    // Strip Markdown code fences like ```json ... ``` or ``` ... ```.
    final fence = RegExp(r'```(?:json|JSON)?\s*([\s\S]*?)```');
    final fenceMatch = fence.firstMatch(working);
    if (fenceMatch != null) {
      working = fenceMatch.group(1)!.trim();
    }

    // Trim to brace/bracket-balanced region if it still has noise around it.
    final s = working.indexOf(openChar);
    if (s != -1) {
      final balanced = _balancedSlice(working, s, openChar, closeChar);
      if (balanced != null) working = balanced;
    }

    return working.trim();
  }

  /// Returns the substring starting at [start] that ends at the matching
  /// closing character, respecting string literals/escapes. Returns null when
  /// no balanced span is found.
  String? _balancedSlice(
    String source,
    int start,
    String openChar,
    String closeChar,
  ) {
    var depth = 0;
    var inString = false;
    var escape = false;
    for (var i = start; i < source.length; i++) {
      final ch = source[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (ch == r'\') {
        escape = true;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (ch == openChar) depth++;
      if (ch == closeChar) {
        depth--;
        if (depth == 0) return source.substring(start, i + 1);
      }
    }
    return null;
  }

  /// Produces a list of progressively cleaned-up JSON candidates to try.
  List<String> _sanitizeAttempts(String candidate) {
    final attempts = <String>{candidate};

    // Normalize curly quotes and other unicode quote variants.
    String normalized = candidate
        .replaceAll('\u201C', '"')
        .replaceAll('\u201D', '"')
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u00A0', ' ');
    attempts.add(normalized);

    // Remove trailing commas before } or ].
    final noTrailingCommas = normalized.replaceAll(
      RegExp(r',\s*(?=[}\]])'),
      '',
    );
    attempts.add(noTrailingCommas);

    // Escape raw newlines/tabs that appear inside string literals (a common
    // small-model mistake that breaks jsonDecode with "unexpected character").
    final escapedStrings = _escapeRawControlCharsInStrings(noTrailingCommas);
    attempts.add(escapedStrings);

    return attempts.toList();
  }

  String _escapeRawControlCharsInStrings(String input) {
    final buffer = StringBuffer();
    var inString = false;
    var escape = false;
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if (escape) {
        buffer.write(ch);
        escape = false;
        continue;
      }
      if (ch == r'\') {
        buffer.write(ch);
        escape = true;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        buffer.write(ch);
        continue;
      }
      if (inString) {
        switch (ch) {
          case '\n':
            buffer.write(r'\n');
            continue;
          case '\r':
            buffer.write(r'\r');
            continue;
          case '\t':
            buffer.write(r'\t');
            continue;
        }
      }
      buffer.write(ch);
    }
    return buffer.toString();
  }

  String _unescape(String value) {
    return value
        .replaceAll(r'\"', '"')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\\', r'\');
  }

  Future<void> dispose() async {
    await _engine?.dispose();
    _engine = null;
  }

  bool get _useCloudBackend =>
      _settings.aiBackendProvider != AiBackendProvider.local &&
      _settings.selectedCloudBackendConfigured;
}
