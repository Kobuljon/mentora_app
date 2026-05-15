import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Singleton wrapper around the device's native TTS engine.
class TtsService {
  TtsService._() {
    _init();
  }

  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();

  /// Currently-speaking message id, or null if idle. Listen via [speakingId].
  final ValueNotifier<String?> speakingId = ValueNotifier<String?>(null);

  Future<void> _init() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    _tts.setCompletionHandler(() => speakingId.value = null);
    _tts.setCancelHandler(() => speakingId.value = null);
    _tts.setErrorHandler((_) => speakingId.value = null);
  }

  /// Speaks [text]. If something is already playing, stops it first.
  /// [id] identifies the message so the UI can show a "speaking" state.
  Future<void> speak(String id, String text) async {
    final cleaned = _stripFormatting(text);
    if (cleaned.isEmpty) return;
    await _tts.stop();
    speakingId.value = id;
    await _tts.speak(cleaned);
  }

  Future<void> stop() async {
    await _tts.stop();
    speakingId.value = null;
  }

  /// Removes markdown, code fences, and LaTeX so the engine reads plain prose.
  String _stripFormatting(String input) {
    var s = input;
    // Code fences
    s = s.replaceAll(RegExp(r'```[\s\S]*?```'), ' ');
    // Inline code
    s = s.replaceAll(RegExp(r'`[^`]*`'), ' ');
    // Block math $$...$$
    s = s.replaceAll(RegExp(r'\$\$[\s\S]*?\$\$'), ' ');
    // Inline math $...$
    s = s.replaceAll(RegExp(r'\$[^\$]+\$'), ' ');
    // Headings, list bullets, blockquotes
    s = s.replaceAll(RegExp(r'^[#>\-\*\+]+\s*', multiLine: true), '');
    // Bold / italic markers
    s = s.replaceAll(RegExp(r'(\*\*|__|\*|_)'), '');
    // Links [text](url) -> text
    s = s.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), (m) => m[1]!);
    // Collapse whitespace
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }
}
