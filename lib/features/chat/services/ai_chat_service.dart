import 'dart:async';

import 'package:flutter_litert_lm/flutter_litert_lm.dart';

import '../../../core/services/cloud_ai_service.dart';
import '../../../core/services/optimized_litert_engine_factory.dart';
import '../../onboarding/services/model_download_service.dart';
import '../../settings/providers/settings_provider.dart';

class AiChatService {
  static const _systemInstruction =
      'You are Mentora, a helpful English teacher for 12-16 year old students. '
      'Do not give programming-related examples. Use everyday adolescent concepts.';

  AiChatService(this._settings);

  final AppSettings _settings;
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
    if (_useCloudBackend) {
      var fullResponse = '';
      await for (final partialText in _sendCloudMessageStream(
        text,
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
            text.isNotEmpty ? text : 'Tell me about this image.',
          ),
        ]);
        yield response.text;
      } catch (_) {
        yield 'Sorry, the current model does not support image input. Please use a vision-capable model or ask a text question instead.';
      }
    } else {
      var fullResponse = '';
      await for (final chunk in conversation.sendMessageStream(text)) {
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
    String text, {
    String? imagePath,
  }) async* {
    var fullResponse = '';
    await for (final delta in CloudAiService(_settings).generateStream(
      systemInstruction: _systemInstruction,
      prompt: _buildCloudPrompt(text),
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
}
