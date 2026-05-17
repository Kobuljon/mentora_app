import 'dart:async';
import 'dart:convert';
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
    final systemInstruction =
        "You are a helpful English teacher. Based only on the provided study text, generate exactly $count questions. "
        "Questions must test understanding of the actual material, not generic English knowledge. "
        "Use clear language for 12-16 year old learners.\n\n"
        "=== REQUIRED OUTPUT FORMAT ===\n"
        "Return ONLY a single JSON array of strings, wrapped exactly between the literal markers [[JSON_START]] and [[JSON_END]].\n"
        "Rules (all are MANDATORY):\n"
        "1. No prose, no commentary, no Markdown, no code fences before, between, or after the markers.\n"
        "2. Use ONLY straight ASCII double quotes (\") for strings. Never use smart quotes (\u201C \u201D \u2018 \u2019).\n"
        "3. Each question is one JSON string. No newlines, tabs, or control characters inside a string. Keep each question on one line.\n"
        "4. Separate strings with a comma. No trailing comma before the closing ].\n"
        "5. Produce exactly $count items \u2014 no more, no fewer.\n"
        "6. Escape any internal double quotes as \\\".\n\n"
        'Exact shape: [[JSON_START]]["Question 1?", "Question 2?"][[JSON_END]]';

    if (_useCloudBackend) {
      final responseText = await CloudAiService(_settings).generate(
        systemInstruction: systemInstruction,
        prompt: 'Text context: $textContext',
      );
      return _parseJsonArray(responseText);
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
      await for (final chunk in conversation.sendMessageStream(
        'Text context: $textContext',
      )) {
        responseText += chunk.text;
      }
      return _parseJsonArray(responseText);
    } finally {
      await conversation.dispose();
    }
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

  List<String> _parseJsonArray(String text) {
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
          return decoded.map((e) => e.toString()).toList();
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
