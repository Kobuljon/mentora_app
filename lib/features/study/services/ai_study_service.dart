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
        "You are a helpful English teacher. Based on the provided text, generate exactly $count questions. "
        "Provide the output strictly as a JSON array of strings, surrounded by [[JSON_START]] and [[JSON_END]] markers. "
        "IMPORTANT: Each string in the array must be separated by a comma. "
        'Example: [[JSON_START]] ["Question 1", "Question 2"] [[JSON_END]]';

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
        "You are a helpful English teacher evaluating a student's answers. "
        "Provide your feedback strictly as a JSON object, surrounded by [[JSON_START]] and [[JSON_END]] markers. "
        "The JSON must have the following schema: "
        '{"evaluations": [{"questionIndex": 0, "isCorrect": true, "feedback": "...", "grammarFeedback": "...(optional)"}], "overallFeedback": "..."}';

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
    try {
      final startIndex = text.indexOf('[[JSON_START]]');
      final endIndex = text.indexOf('[[JSON_END]]');

      String jsonStr = text;
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        jsonStr = text
            .substring(startIndex + '[[JSON_START]]'.length, endIndex)
            .trim();
      } else {
        final s = text.indexOf('[');
        final e = text.lastIndexOf(']');
        if (s != -1 && e != -1 && e > s) {
          jsonStr = text.substring(s, e + 1);
        }
      }

      try {
        final List<dynamic> parsed = jsonDecode(jsonStr);
        return parsed.map((e) => e.toString()).toList();
      } catch (_) {
        // Fallback: If AI forgot commas between array items, extract quoted strings directly
        final exp = RegExp(r'"([^"]+)"');
        final matches = exp.allMatches(jsonStr);
        final list = matches.map((m) => m.group(1)!).toList();
        if (list.isNotEmpty) return list;
        rethrow;
      }
    } catch (e) {
      throw FormatException(
        'Failed to parse AI response: $e\\nResponse was: $text',
      );
    }
  }

  Map<String, dynamic> _parseJsonObject(String text) {
    try {
      final startIndex = text.indexOf('[[JSON_START]]');
      final endIndex = text.indexOf('[[JSON_END]]');

      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        final jsonStr = text
            .substring(startIndex + '[[JSON_START]]'.length, endIndex)
            .trim();
        return jsonDecode(jsonStr) as Map<String, dynamic>;
      }

      // Fallback
      final s = text.indexOf('{');
      final e = text.lastIndexOf('}');
      if (s != -1 && e != -1 && e > s) {
        return jsonDecode(text.substring(s, e + 1)) as Map<String, dynamic>;
      }

      throw FormatException('Could not find JSON object in response');
    } catch (e) {
      throw FormatException(
        'Failed to parse AI response: $e\\nResponse was: $text',
      );
    }
  }

  Future<void> dispose() async {
    await _engine?.dispose();
    _engine = null;
  }

  bool get _useCloudBackend =>
      _settings.aiBackendProvider != AiBackendProvider.local &&
      _settings.selectedCloudBackendConfigured;
}
