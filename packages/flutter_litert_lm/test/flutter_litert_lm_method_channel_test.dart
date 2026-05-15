import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_litert_lm/flutter_litert_lm_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelFlutterLitertLm();
  const channel = MethodChannel('flutter_litert_lm');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'createEngine':
              return 'engine-123';
            case 'createConversation':
              return 'conv-456';
            case 'sendMessage':
              return {
                'role': 'model',
                'text': 'Hello!',
                'toolCalls': <Map<String, dynamic>>[],
              };
            case 'countTokens':
              return 5;
            case 'hasSpeculativeDecodingSupport':
              return true;
            case 'getBenchmarkInfo':
              return {
                'initTimeInSecond': 0.1,
                'timeToFirstTokenInSecond': 0.2,
                'lastPrefillTokenCount': 4,
                'lastDecodeTokenCount': 8,
                'lastPrefillTokensPerSecond': 20.0,
                'lastDecodeTokensPerSecond': 30.0,
              };
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('createEngine returns engine ID', () async {
    final id = await platform.createEngine({'modelPath': '/test.litertlm'});
    expect(id, 'engine-123');
  });

  test('createConversation returns conversation ID', () async {
    final id = await platform.createConversation('engine-123', null);
    expect(id, 'conv-456');
  });

  test('sendMessage returns response map', () async {
    final result = await platform.sendMessage('conv-456', [
      {'type': 'text', 'text': 'Hi'},
    ], null);
    expect(result['text'], 'Hello!');
    expect(result['role'], 'model');
  });

  test('countTokens returns count', () async {
    final count = await platform.countTokens('engine-123', 'Hello world');
    expect(count, 5);
  });

  test('hasSpeculativeDecodingSupport returns support flag', () async {
    final supported = await platform.hasSpeculativeDecodingSupport(
      '/test.litertlm',
    );
    expect(supported, isTrue);
  });

  test('getBenchmarkInfo returns benchmark map', () async {
    final info = await platform.getBenchmarkInfo('conv-456');
    expect(info['lastDecodeTokensPerSecond'], 30.0);
  });
}
