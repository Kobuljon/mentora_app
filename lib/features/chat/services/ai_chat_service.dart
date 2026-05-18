import 'dart:async';

import 'package:flutter_litert_lm/flutter_litert_lm.dart';

import '../../../core/services/cloud_ai_service.dart';
import '../../../core/services/optimized_litert_engine_factory.dart';
import '../../onboarding/services/model_download_service.dart';
import '../../settings/providers/settings_provider.dart';
import 'training_data_search_service.dart';

class AiChatService {
  static const _systemInstruction =
      'You are Mentora, a helpful English teacher for 12-16 year old students. '
      'Do not give programming-related examples. Use everyday adolescent concepts. '
      'When uploaded learning material is provided in the user message, treat it as the primary source and cite it.';

  AiChatService(this._settings, {TrainingDataSearchService? trainingDataSearch})
    : _trainingDataSearch = trainingDataSearch ?? TrainingDataSearchService();

  final AppSettings _settings;
  final TrainingDataSearchService _trainingDataSearch;
  final List<({String role, String text})> _cloudMessages = [];
  LiteLmEngine? _engine;
  LiteLmConversation? _conversation;

  Future<void> initialize({String? modelPath}) async {
    if (_useCloudBackend) return;
    if (_conversation != null) return;

    final resolvedModelPath = modelPath ?? await _resolveModelPath();

    _engine = await OptimizedLiteRtEngineFactory.create(
      modelPath: resolvedModelPath,
      enableVision: true,
    );

    _conversation = await _engine!.createConversation(
      const LiteLmConversationConfig(
        systemInstruction: _systemInstruction,
        automaticToolCalling: false,
      ),
    );
  }

  Stream<String> sendMessage(String text, {String? imagePath}) async* {
    final modelPrompt = await _buildModelPrompt(text, imagePath: imagePath);

    if (_useCloudBackend) {
      var fullResponse = '';
      await for (final partialText in _sendCloudMessageStream(
        modelPrompt,
        imagePath: imagePath,
      )) {
        fullResponse = partialText;
        yield partialText;
      }
      _cloudMessages
        ..add((role: 'user', text: text))
        ..add((role: 'assistant', text: fullResponse));
      return;
    }

    final conversation = _conversation;
    if (conversation == null) {
      throw StateError('AiChatService.initialize() must be called first.');
    }

    if (imagePath != null) {
      try {
        final response = await conversation.sendMultimodalMessage([
          LiteLmContent.imageFile(imagePath),
          LiteLmContent.text(
            modelPrompt.isNotEmpty ? modelPrompt : 'Tell me about this image.',
          ),
        ]);
        yield response.text;
      } catch (_) {
        yield 'Sorry, the current model does not support image input. Please use a vision-capable model or ask a text question instead.';
      }
    } else {
      var fullResponse = '';
      await for (final chunk in conversation.sendMessageStream(modelPrompt)) {
        fullResponse += chunk.text;
        yield fullResponse;
      }
    }
  }

  Future<void> dispose() async {
    await _conversation?.dispose();
    await _engine?.dispose();
    _conversation = null;
    _engine = null;
    _cloudMessages.clear();
  }

  Future<void> resetConversation() async {
    await _conversation?.dispose();
    _conversation = null;
    _cloudMessages.clear();
  }

  Future<String> _resolveModelPath() async {
    return ModelDownloadService.instance.getReadyModelPath();
  }

  bool get _useCloudBackend =>
      _settings.aiBackendProvider != AiBackendProvider.local &&
      _settings.selectedCloudBackendConfigured;

  Stream<String> _sendCloudMessageStream(
    String modelPrompt, {
    String? imagePath,
  }) async* {
    var fullResponse = '';
    await for (final delta in CloudAiService(_settings).generateStream(
      systemInstruction: _systemInstruction,
      prompt: _buildCloudPrompt(modelPrompt),
      imagePath: imagePath,
    )) {
      fullResponse += delta;
      yield fullResponse;
    }
  }

  String _buildCloudPrompt(String text) {
    final recentMessages = _cloudMessages.length <= 12
        ? _cloudMessages
        : _cloudMessages.sublist(_cloudMessages.length - 12);
    if (recentMessages.isEmpty) return text;

    final history = recentMessages
        .map((message) => '${message.role}: ${message.text}')
        .join('\n');
    return 'Conversation so far:\n$history\n\nUser: $text';
  }

  Future<String> _buildModelPrompt(String text, {String? imagePath}) async {
    final query = text.trim();
    if (query.isEmpty) return text;

    final matches = await _trainingDataSearch.search(query);
    if (matches.isEmpty) return text;

    final snippets = matches.indexed
        .map((entry) {
          final index = entry.$1 + 1;
          final match = entry.$2;
          return '[$index] Source: ${match.sourceLabel}\n${match.content}';
        })
        .join('\n\n');

    final imageInstruction = imagePath == null
        ? ''
        : '\nThe student also attached an image. Use the image together with these snippets if both are relevant.';

    return '''
Use Mentora's uploaded learning material snippets as the main source when they are relevant, especially when the student asks about uploaded materials, notes, lessons, files, review, flashcards, or quizzes.
If the snippets do not contain the answer, say that you could not find it in the uploaded materials, then give a brief general answer if it helps.
Cite sources inline using the provided source labels, for example [filename, page 2].$imageInstruction

Uploaded learning material snippets:
$snippets

Student question:
$text
''';
  }
}
