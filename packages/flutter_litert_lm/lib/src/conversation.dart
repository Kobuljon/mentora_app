import '../flutter_litert_lm_platform_interface.dart';
import 'content.dart';
import 'message.dart';

/// A conversation session with a loaded LLM model.
///
/// Use [LiteLmEngine.createConversation] to obtain an instance.
/// Remember to call [dispose] when done.
class LiteLmConversation {
  final String _id;
  bool _disposed = false;

  LiteLmConversation._(this._id);

  /// Internal factory — called by engine.
  static LiteLmConversation fromId(String id) => LiteLmConversation._(id);

  /// The native conversation ID.
  String get id => _id;

  /// Send a text message and get the complete response.
  Future<LiteLmMessage> sendMessage(
    String text, {
    Map<String, Object>? extraContext,
  }) async {
    _ensureNotDisposed();
    final contents = [LiteLmContent.text(text).toMap()];
    final result = await FlutterLitertLmPlatform.instance.sendMessage(
      _id,
      contents,
      extraContext,
    );
    return LiteLmMessage.fromMap(result);
  }

  /// Send multimodal contents (text + images + audio) and get the complete response.
  Future<LiteLmMessage> sendMultimodalMessage(
    List<LiteLmContent> contents, {
    Map<String, Object>? extraContext,
  }) async {
    _ensureNotDisposed();
    final result = await FlutterLitertLmPlatform.instance.sendMessage(
      _id,
      contents.map((c) => c.toMap()).toList(),
      extraContext,
    );
    return LiteLmMessage.fromMap(result);
  }

  /// Send a text message and stream back partial responses as tokens are generated.
  Stream<LiteLmMessage> sendMessageStream(
    String text, {
    Map<String, Object>? extraContext,
  }) {
    _ensureNotDisposed();
    final contents = [LiteLmContent.text(text).toMap()];
    return FlutterLitertLmPlatform.instance
        .sendMessageStream(_id, contents, extraContext)
        .map((map) => LiteLmMessage.fromMap(map));
  }

  /// Send a tool response back to the model.
  Future<LiteLmMessage> sendToolResponse(
    String toolName,
    String result, {
    Map<String, Object>? extraContext,
  }) async {
    _ensureNotDisposed();
    final contents = [LiteLmContent.toolResponse(toolName, result).toMap()];
    final response = await FlutterLitertLmPlatform.instance.sendMessage(
      _id,
      contents,
      extraContext,
    );
    return LiteLmMessage.fromMap(response);
  }

  /// Release native resources for this conversation.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await FlutterLitertLmPlatform.instance.disposeConversation(_id);
  }

  /// Get native benchmark counters for the most recent response.
  Future<LiteLmBenchmarkInfo> getBenchmarkInfo() async {
    _ensureNotDisposed();
    final map = await FlutterLitertLmPlatform.instance.getBenchmarkInfo(_id);
    return LiteLmBenchmarkInfo.fromMap(map);
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('Conversation has been disposed');
    }
  }
}

class LiteLmBenchmarkInfo {
  const LiteLmBenchmarkInfo({
    required this.initTimeInSecond,
    required this.timeToFirstTokenInSecond,
    required this.lastPrefillTokenCount,
    required this.lastDecodeTokenCount,
    required this.lastPrefillTokensPerSecond,
    required this.lastDecodeTokensPerSecond,
  });

  final double initTimeInSecond;
  final double timeToFirstTokenInSecond;
  final int lastPrefillTokenCount;
  final int lastDecodeTokenCount;
  final double lastPrefillTokensPerSecond;
  final double lastDecodeTokensPerSecond;

  factory LiteLmBenchmarkInfo.fromMap(Map<String, dynamic> map) {
    return LiteLmBenchmarkInfo(
      initTimeInSecond: (map['initTimeInSecond'] as num?)?.toDouble() ?? 0,
      timeToFirstTokenInSecond:
          (map['timeToFirstTokenInSecond'] as num?)?.toDouble() ?? 0,
      lastPrefillTokenCount:
          (map['lastPrefillTokenCount'] as num?)?.toInt() ?? 0,
      lastDecodeTokenCount: (map['lastDecodeTokenCount'] as num?)?.toInt() ?? 0,
      lastPrefillTokensPerSecond:
          (map['lastPrefillTokensPerSecond'] as num?)?.toDouble() ?? 0,
      lastDecodeTokensPerSecond:
          (map['lastDecodeTokensPerSecond'] as num?)?.toDouble() ?? 0,
    );
  }
}
