import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_litert_lm/flutter_litert_lm.dart';
import 'package:flutter_litert_lm/flutter_litert_lm_platform_interface.dart';
import 'package:flutter_litert_lm/flutter_litert_lm_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterLitertLmPlatform
    with MockPlatformInterfaceMixin
    implements FlutterLitertLmPlatform {
  @override
  Future<String> createEngine(Map<String, dynamic> config) async => 'engine-1';

  @override
  Future<void> disposeEngine(String engineId) async {}

  @override
  Future<String> createConversation(
    String engineId,
    Map<String, dynamic>? config,
  ) async => 'conv-1';

  @override
  Future<void> disposeConversation(String conversationId) async {}

  @override
  Future<Map<String, dynamic>> sendMessage(
    String conversationId,
    List<Map<String, dynamic>> contents,
    Map<String, Object>? extraContext,
  ) async => {
    'role': 'model',
    'text': 'Hello from mock!',
    'toolCalls': <Map<String, dynamic>>[],
  };

  @override
  Stream<Map<String, dynamic>> sendMessageStream(
    String conversationId,
    List<Map<String, dynamic>> contents,
    Map<String, Object>? extraContext,
  ) {
    return Stream.fromIterable([
      {'role': 'model', 'text': 'Hello', 'toolCalls': []},
      {'role': 'model', 'text': 'Hello from mock!', 'toolCalls': []},
    ]);
  }

  @override
  Future<int> countTokens(String engineId, String text) async => text.length;

  @override
  Future<bool> hasSpeculativeDecodingSupport(String modelPath) async => true;

  @override
  Future<Map<String, dynamic>> getBenchmarkInfo(String conversationId) async =>
      {
        'initTimeInSecond': 0.1,
        'timeToFirstTokenInSecond': 0.2,
        'lastPrefillTokenCount': 4,
        'lastDecodeTokenCount': 8,
        'lastPrefillTokensPerSecond': 20.0,
        'lastDecodeTokensPerSecond': 30.0,
      };
}

void main() {
  final initialPlatform = FlutterLitertLmPlatform.instance;

  test('MethodChannelFlutterLitertLm is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterLitertLm>());
  });

  group('LiteLmEngine', () {
    late MockFlutterLitertLmPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockFlutterLitertLmPlatform();
      FlutterLitertLmPlatform.instance = mockPlatform;
    });

    test('create returns engine', () async {
      final engine = await LiteLmEngine.create(
        const LiteLmEngineConfig(modelPath: '/test/model.litertlm'),
      );
      expect(engine.id, 'engine-1');
      await engine.dispose();
    });

    test('createConversation returns conversation', () async {
      final engine = await LiteLmEngine.create(
        const LiteLmEngineConfig(modelPath: '/test/model.litertlm'),
      );
      final conv = await engine.createConversation();
      expect(conv.id, 'conv-1');
      await conv.dispose();
      await engine.dispose();
    });

    test('disposed engine throws', () async {
      final engine = await LiteLmEngine.create(
        const LiteLmEngineConfig(modelPath: '/test/model.litertlm'),
      );
      await engine.dispose();
      expect(() => engine.createConversation(), throwsStateError);
    });
  });

  group('LiteLmConversation', () {
    late MockFlutterLitertLmPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockFlutterLitertLmPlatform();
      FlutterLitertLmPlatform.instance = mockPlatform;
    });

    test('sendMessage returns response', () async {
      final engine = await LiteLmEngine.create(
        const LiteLmEngineConfig(modelPath: '/test/model.litertlm'),
      );
      final conv = await engine.createConversation();
      final response = await conv.sendMessage('Hi');
      expect(response.text, 'Hello from mock!');
      expect(response.role, LiteLmRole.model);
      await conv.dispose();
      await engine.dispose();
    });

    test('sendMessageStream emits messages', () async {
      final engine = await LiteLmEngine.create(
        const LiteLmEngineConfig(modelPath: '/test/model.litertlm'),
      );
      final conv = await engine.createConversation();
      final messages = await conv.sendMessageStream('Hi').toList();
      expect(messages.length, 2);
      expect(messages.last.text, 'Hello from mock!');
      await conv.dispose();
      await engine.dispose();
    });

    test('disposed conversation throws', () async {
      final engine = await LiteLmEngine.create(
        const LiteLmEngineConfig(modelPath: '/test/model.litertlm'),
      );
      final conv = await engine.createConversation();
      await conv.dispose();
      expect(() => conv.sendMessage('Hi'), throwsStateError);
      await engine.dispose();
    });
  });

  group('Models', () {
    test('SamplerConfig toMap', () {
      const config = LiteLmSamplerConfig(topK: 50, topP: 0.9, temperature: 1.0);
      final map = config.toMap();
      expect(map['topK'], 50);
      expect(map['topP'], 0.9);
      expect(map['temperature'], 1.0);
    });

    test('LiteLmTool roundtrip', () {
      final tool = LiteLmTool(
        name: 'test',
        description: 'A test tool',
        parameters: {'type': 'object'},
      );
      final map = tool.toMap();
      final restored = LiteLmTool.fromMap(map);
      expect(restored.name, 'test');
      expect(restored.description, 'A test tool');
    });

    test('Message.user creates correct message', () {
      final msg = LiteLmMessage.user('Hello');
      expect(msg.role, LiteLmRole.user);
      expect(msg.text, 'Hello');
    });

    test('EngineConfig exposes performance options', () {
      const config = LiteLmEngineConfig(
        modelPath: '/test/model.litertlm',
        backend: LiteLmBackend.cpu,
        cpuThreads: 8,
        maxNumTokens: 8192,
        maxNumImages: 2,
        enableSpeculativeDecoding: true,
        enableBenchmark: true,
      );
      final map = config.toMap();
      expect(map['cpuThreads'], 8);
      expect(map['maxNumTokens'], 8192);
      expect(map['maxNumImages'], 2);
      expect(map['enableSpeculativeDecoding'], isTrue);
      expect(map['enableBenchmark'], isTrue);
    });

    test('BenchmarkInfo parses native counters', () {
      final info = LiteLmBenchmarkInfo.fromMap({
        'initTimeInSecond': 0.1,
        'timeToFirstTokenInSecond': 0.2,
        'lastPrefillTokenCount': 4,
        'lastDecodeTokenCount': 8,
        'lastPrefillTokensPerSecond': 20.0,
        'lastDecodeTokensPerSecond': 30.0,
      });
      expect(info.lastDecodeTokensPerSecond, 30.0);
      expect(info.lastDecodeTokenCount, 8);
    });
  });
}
