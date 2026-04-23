import 'dart:async';

import 'package:flutter_litert_lm/flutter_litert_lm.dart';
import 'package:path_provider/path_provider.dart';

import '../../onboarding/services/model_download_service.dart';

class AiChatService {
  static const _systemInstruction =
      'You are Mentora, a helpful English teacher for 12-16 year old students. Do not give programming-related examples in your explanations, use everyday adolescent concepts.';

  LiteLmEngine? _engine;
  LiteLmConversation? _conversation;

  Future<void> initialize({String? modelPath}) async {
    if (_conversation != null) return;

    final cacheDir = await getTemporaryDirectory();
    final resolvedModelPath = modelPath ?? await _resolveModelPath();

    _engine = await LiteLmEngine.create(
      LiteLmEngineConfig(
        modelPath: resolvedModelPath,
        backend: LiteLmBackend.cpu,
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

  Stream<String> sendMessage(String text) async* {
    final conversation = _conversation;
    if (conversation == null) {
      throw StateError('AiChatService.initialize() must be called first.');
    }

    var currentText = '';
    await for (final chunk in conversation.sendMessageStream(text)) {
      currentText = _mergePartialText(currentText, chunk.text);
      yield currentText;
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

  String _mergePartialText(String previous, String incoming) {
    if (incoming.isEmpty) return previous;
    if (previous.isEmpty) return incoming;
    if (incoming.startsWith(previous)) return incoming;
    if (previous.endsWith(incoming)) return previous;
    return '$previous$incoming';
  }
}
