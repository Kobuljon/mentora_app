import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../features/settings/providers/settings_provider.dart';

class CloudAiService {
  CloudAiService(this.settings, {Dio? dio}) : _dio = dio ?? Dio();

  final AppSettings settings;
  final Dio _dio;

  bool get isConfigured => settings.selectedCloudBackendConfigured;

  Future<String> generate({
    required String systemInstruction,
    required String prompt,
    String? imagePath,
  }) async {
    if (!isConfigured) {
      throw StateError('Selected cloud AI provider is not configured.');
    }

    return switch (settings.aiBackendProvider) {
      AiBackendProvider.local => throw StateError('Local backend selected.'),
      AiBackendProvider.openAi => _generateOpenAi(
        systemInstruction: systemInstruction,
        prompt: prompt,
        imagePath: imagePath,
      ),
      AiBackendProvider.azureOpenAi => _generateAzureOpenAi(
        systemInstruction: systemInstruction,
        prompt: prompt,
        imagePath: imagePath,
      ),
      AiBackendProvider.gemini => _generateGemini(
        systemInstruction: systemInstruction,
        prompt: prompt,
        imagePath: imagePath,
      ),
    };
  }

  Stream<String> generateStream({
    required String systemInstruction,
    required String prompt,
    String? imagePath,
  }) async* {
    if (!isConfigured) {
      throw StateError('Selected cloud AI provider is not configured.');
    }

    switch (settings.aiBackendProvider) {
      case AiBackendProvider.local:
        throw StateError('Local backend selected.');
      case AiBackendProvider.openAi:
        yield* _streamOpenAi(
          systemInstruction: systemInstruction,
          prompt: prompt,
          imagePath: imagePath,
        );
      case AiBackendProvider.azureOpenAi:
        yield* _streamAzureOpenAi(
          systemInstruction: systemInstruction,
          prompt: prompt,
          imagePath: imagePath,
        );
      case AiBackendProvider.gemini:
        yield* _streamGemini(
          systemInstruction: systemInstruction,
          prompt: prompt,
          imagePath: imagePath,
        );
    }
  }

  Future<String> _generateOpenAi({
    required String systemInstruction,
    required String prompt,
    String? imagePath,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'https://api.openai.com/v1/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer ${settings.openAiApiKey.trim()}',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'model': settings.openAiModel.trim(),
        'messages': [
          {'role': 'system', 'content': systemInstruction},
          {
            'role': 'user',
            'content': await _openAiUserContent(prompt, imagePath),
          },
        ],
      },
    );

    return _extractOpenAiText(response.data);
  }

  Stream<String> _streamOpenAi({
    required String systemInstruction,
    required String prompt,
    String? imagePath,
  }) async* {
    final response = await _dio.post<ResponseBody>(
      'https://api.openai.com/v1/chat/completions',
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Authorization': 'Bearer ${settings.openAiApiKey.trim()}',
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        },
      ),
      data: {
        'model': settings.openAiModel.trim(),
        'stream': true,
        'messages': [
          {'role': 'system', 'content': systemInstruction},
          {
            'role': 'user',
            'content': await _openAiUserContent(prompt, imagePath),
          },
        ],
      },
    );

    yield* _streamSseText(response.data!, _extractOpenAiStreamDelta);
  }

  Future<String> _generateAzureOpenAi({
    required String systemInstruction,
    required String prompt,
    String? imagePath,
  }) async {
    final endpoint = _normalizeEndpoint(settings.azureOpenAiEndpoint);
    final deployment = Uri.encodeComponent(
      settings.azureOpenAiDeployment.trim(),
    );
    final apiVersion = Uri.encodeQueryComponent(
      settings.azureOpenAiApiVersion.trim(),
    );
    final response = await _dio.post<Map<String, dynamic>>(
      '$endpoint/openai/deployments/$deployment/chat/completions?api-version=$apiVersion',
      options: Options(
        headers: {
          'api-key': settings.azureOpenAiApiKey.trim(),
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'messages': [
          {'role': 'system', 'content': systemInstruction},
          {
            'role': 'user',
            'content': await _openAiUserContent(prompt, imagePath),
          },
        ],
      },
    );

    return _extractOpenAiText(response.data);
  }

  Stream<String> _streamAzureOpenAi({
    required String systemInstruction,
    required String prompt,
    String? imagePath,
  }) async* {
    final endpoint = _normalizeEndpoint(settings.azureOpenAiEndpoint);
    final deployment = Uri.encodeComponent(
      settings.azureOpenAiDeployment.trim(),
    );
    final apiVersion = Uri.encodeQueryComponent(
      settings.azureOpenAiApiVersion.trim(),
    );
    final response = await _dio.post<ResponseBody>(
      '$endpoint/openai/deployments/$deployment/chat/completions?api-version=$apiVersion',
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'api-key': settings.azureOpenAiApiKey.trim(),
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        },
      ),
      data: {
        'stream': true,
        'messages': [
          {'role': 'system', 'content': systemInstruction},
          {
            'role': 'user',
            'content': await _openAiUserContent(prompt, imagePath),
          },
        ],
      },
    );

    yield* _streamSseText(response.data!, _extractOpenAiStreamDelta);
  }

  Future<String> _generateGemini({
    required String systemInstruction,
    required String prompt,
    String? imagePath,
  }) async {
    final model = Uri.encodeComponent(settings.geminiModel.trim());
    final response = await _dio.post<Map<String, dynamic>>(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
      options: Options(
        headers: {
          'x-goog-api-key': settings.geminiApiKey.trim(),
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'system_instruction': {
          'parts': [
            {'text': systemInstruction},
          ],
        },
        'contents': [
          {'role': 'user', 'parts': await _geminiParts(prompt, imagePath)},
        ],
      },
    );

    final candidates = response.data?['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw StateError('Gemini returned no candidates.');
    }

    final content = candidates.first['content'];
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List) return '';

    return parts
        .whereType<Map>()
        .map((part) => part['text'])
        .whereType<String>()
        .join()
        .trim();
  }

  Stream<String> _streamGemini({
    required String systemInstruction,
    required String prompt,
    String? imagePath,
  }) async* {
    final model = Uri.encodeComponent(settings.geminiModel.trim());
    final response = await _dio.post<ResponseBody>(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:streamGenerateContent?alt=sse',
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'x-goog-api-key': settings.geminiApiKey.trim(),
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        },
      ),
      data: {
        'system_instruction': {
          'parts': [
            {'text': systemInstruction},
          ],
        },
        'contents': [
          {'role': 'user', 'parts': await _geminiParts(prompt, imagePath)},
        ],
      },
    );

    yield* _streamSseText(response.data!, _extractGeminiStreamDelta);
  }

  Future<Object> _openAiUserContent(String prompt, String? imagePath) async {
    if (imagePath == null) return prompt;

    return [
      {
        'type': 'text',
        'text': prompt.isEmpty ? 'Tell me about this image.' : prompt,
      },
      {
        'type': 'image_url',
        'image_url': {'url': await _dataUriForImage(imagePath)},
      },
    ];
  }

  Future<List<Map<String, Object>>> _geminiParts(
    String prompt,
    String? imagePath,
  ) async {
    final parts = <Map<String, Object>>[
      {'text': prompt.isEmpty ? 'Tell me about this image.' : prompt},
    ];
    if (imagePath != null) {
      final bytes = await File(imagePath).readAsBytes();
      parts.add({
        'inline_data': {
          'mime_type': _mimeTypeForPath(imagePath),
          'data': base64Encode(bytes),
        },
      });
    }
    return parts;
  }

  Future<String> _dataUriForImage(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    return 'data:${_mimeTypeForPath(imagePath)};base64,${base64Encode(bytes)}';
  }

  String _extractOpenAiText(Map<String, dynamic>? data) {
    final choices = data?['choices'];
    if (choices is! List || choices.isEmpty) {
      throw StateError('AI provider returned no choices.');
    }

    final message = choices.first['message'];
    if (message is! Map) return '';

    final content = message['content'];
    if (content is String) return content.trim();
    if (content is List) {
      return content
          .whereType<Map>()
          .map((part) => part['text'])
          .whereType<String>()
          .join()
          .trim();
    }
    return '';
  }

  Stream<String> _streamSseText(
    ResponseBody responseBody,
    String Function(Map<String, dynamic> data) extractText,
  ) async* {
    var buffer = '';
    await for (final chunk in responseBody.stream) {
      buffer += utf8.decode(chunk, allowMalformed: true);
      while (true) {
        final separatorIndex = buffer.indexOf('\n\n');
        if (separatorIndex == -1) break;

        final event = buffer.substring(0, separatorIndex);
        buffer = buffer.substring(separatorIndex + 2);
        final text = _parseSseEvent(event, extractText);
        if (text != null && text.isNotEmpty) yield text;
      }
    }

    final trailing = _parseSseEvent(buffer, extractText);
    if (trailing != null && trailing.isNotEmpty) yield trailing;
  }

  String? _parseSseEvent(
    String event,
    String Function(Map<String, dynamic> data) extractText,
  ) {
    final dataLines = event
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.startsWith('data:'))
        .map((line) => line.substring(5).trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (dataLines.isEmpty) return null;

    final payload = dataLines.join('\n');
    if (payload == '[DONE]') return null;

    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) return null;
    return extractText(decoded);
  }

  String _extractOpenAiStreamDelta(Map<String, dynamic> data) {
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) return '';
    final delta = choices.first['delta'];
    if (delta is! Map) return '';
    final content = delta['content'];
    if (content is String) return content;
    if (content is List) {
      return content
          .whereType<Map>()
          .map((part) => part['text'])
          .whereType<String>()
          .join();
    }
    return '';
  }

  String _extractGeminiStreamDelta(Map<String, dynamic> data) {
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) return '';
    final content = candidates.first['content'];
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List) return '';

    return parts
        .whereType<Map>()
        .map((part) => part['text'])
        .whereType<String>()
        .join();
  }

  String _normalizeEndpoint(String endpoint) {
    final trimmed = endpoint.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  String _mimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
