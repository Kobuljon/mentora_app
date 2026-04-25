import 'dart:async';

import 'package:flutter_litert_lm/flutter_litert_lm.dart';
import 'package:path_provider/path_provider.dart';

import '../../onboarding/services/model_download_service.dart';

class AiChatService {
  static const _systemInstruction =
      'You are Mentora, a helpful English teacher for 12-16 year old students. '
      'Do not give programming-related examples. Use everyday adolescent concepts.';

  LiteLmEngine? _engine;
  LiteLmConversation? _conversation;

  Future<void> initialize({String? modelPath}) async {
    if (_conversation != null) return;

    final cacheDir = await getTemporaryDirectory();
    final resolvedModelPath = modelPath ?? await _resolveModelPath();

    _engine = await LiteLmEngine.create(
      LiteLmEngineConfig(
        modelPath: resolvedModelPath,
        backend: LiteLmBackend.gpu,
        visionBackend: LiteLmBackend.gpu,
        cacheDir: cacheDir.path,
      ),
    );

    _conversation = await _engine!.createConversation(
      const LiteLmConversationConfig(
        systemInstruction: _systemInstruction,
        automaticToolCalling: false,
      ),
    );
  }

  Stream<String> sendMessage(String text, {String? imagePath}) async* {
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
  }

  Future<String> _resolveModelPath() async {
    return ModelDownloadService.instance.getReadyModelPath();
  }
}
