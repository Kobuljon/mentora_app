import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/services/download_notification_service.dart';

enum ModelVariant { e2b, e4b }

extension ModelVariantExtension on ModelVariant {
  String get url => switch (this) {
    ModelVariant.e2b =>
      'https://mentora-models.mesa.uz/gemma-4-E2B-it.litertlm',
    ModelVariant.e4b =>
      'https://mentora-models.mesa.uz/gemma-4-E4B-it.litertlm',
  };

  String get fileName => switch (this) {
    ModelVariant.e2b => 'gemma-4-E2B-it.litertlm',
    ModelVariant.e4b => 'gemma-4-E4B-it.litertlm',
  };

  String get displayName => switch (this) {
    ModelVariant.e2b => 'Standard Engine (Gemma 4 E2B)',
    ModelVariant.e4b => 'Advanced Engine (Gemma 4 E4B)',
  };

  /// Approximate size in bytes used for disk space pre-check.
  int get approximateSizeBytes => switch (this) {
    ModelVariant.e2b => 2 * 1024 * 1024 * 1024, // ~2 GB
    ModelVariant.e4b => 4 * 1024 * 1024 * 1024, // ~4 GB
  };
}

class DownloadProgress {
  final int received;
  final int total;
  final Duration? estimatedTimeRemaining;

  const DownloadProgress({
    required this.received,
    required this.total,
    this.estimatedTimeRemaining,
  });

  double get fraction => total > 0 ? received / total : 0.0;

  String get receivedLabel => _formatBytes(received);
  String get totalLabel => _formatBytes(total);
  String? get remainingTimeLabel => estimatedTimeRemaining == null
      ? null
      : _formatRemainingTime(estimatedTimeRemaining!);

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double value = bytes.toDouble();
    while (value >= 1024 && i < units.length - 1) {
      value /= 1024;
      i++;
    }
    return '${value.toStringAsFixed(1)} ${units[i]}';
  }

  static String _formatRemainingTime(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds.clamp(1, 59)} sec left';
    }

    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} min left';
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (minutes == 0) {
      return '$hours hr left';
    }

    return '$hours hr $minutes min left';
  }
}

const _prefKeyIsModelReady = 'isModelReady';
const _prefKeyModelPath = 'modelFilePath';

class ModelDownloadService {
  ModelDownloadService._();

  static final ModelDownloadService instance = ModelDownloadService._();

  final Dio _dio = Dio();
  CancelToken? _cancelToken;
  Timer? _notificationTimer;
  ModelVariant? _activeNotificationVariant;
  DownloadProgress? _latestNotificationProgress;
  DateTime? _downloadStartedAt;
  int _downloadStartBytes = 0;

  /// Returns true if a model file has been fully downloaded and is ready.
  Future<bool> isModelReady() async {
    final prefs = await SharedPreferences.getInstance();
    final isReady = prefs.getBool(_prefKeyIsModelReady) ?? false;
    if (!isReady) return false;

    // Double-check the file actually exists on disk.
    final path = prefs.getString(_prefKeyModelPath);
    if (path == null) return false;
    return File(path).existsSync();
  }

  /// Returns the exact local path of the downloaded model file.
  ///
  /// Throws if no fully-downloaded model is currently available.
  Future<String> getReadyModelPath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_prefKeyModelPath);

    if (path == null || path.isEmpty) {
      throw StateError('No downloaded model path is available.');
    }

    if (!File(path).existsSync()) {
      throw StateError('Downloaded model file was not found at $path.');
    }

    return path;
  }

  Future<String> _getModelFilePath(ModelVariant variant) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/${variant.fileName}';
  }

  /// Returns the number of already-downloaded bytes for a partial file, or 0.
  Future<int> _getExistingBytes(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  /// Downloads [variant] to the Application Documents Directory with
  /// resume support. Yields [DownloadProgress] events via [onProgress].
  ///
  /// Keeps the screen on via wakelock for the duration.
  /// On completion marks `isModelReady = true` in SharedPreferences.
  Future<void> downloadModel({
    required ModelVariant variant,
    required void Function(DownloadProgress progress) onProgress,
    void Function(Object error)? onError,
  }) async {
    final filePath = await _getModelFilePath(variant);
    final existingBytes = await _getExistingBytes(filePath);

    await WakelockPlus.enable();
    _cancelToken = CancelToken();

    try {
      final options = Options(
        responseType: ResponseType.stream,
        followRedirects: true,
        headers: existingBytes > 0 ? {'Range': 'bytes=$existingBytes-'} : null,
      );

      final response = await _dio.get<ResponseBody>(
        variant.url,
        options: options,
        cancelToken: _cancelToken,
      );

      final responseBody = response.data!;
      final contentLength =
          int.tryParse(response.headers.value('content-length') ?? '') ?? 0;
      final totalBytes = existingBytes + contentLength;

      final file = File(filePath);
      final sink = file.openWrite(
        mode: existingBytes > 0 ? FileMode.append : FileMode.write,
      );

      int receivedBytes = existingBytes;
      _downloadStartedAt = DateTime.now();
      _downloadStartBytes = existingBytes;

      final initialProgress = DownloadProgress(
        received: receivedBytes,
        total: totalBytes,
        estimatedTimeRemaining: _estimateRemainingTime(
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
        ),
      );
      _startNotificationUpdates(variant, initialProgress);

      await for (final chunk in responseBody.stream) {
        if (_cancelToken?.isCancelled == true) break;
        sink.add(chunk);
        receivedBytes += chunk.length;
        final progress = DownloadProgress(
          received: receivedBytes,
          total: totalBytes,
          estimatedTimeRemaining: _estimateRemainingTime(
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
          ),
        );
        onProgress(progress);
        _latestNotificationProgress = progress;
      }

      await sink.flush();
      await sink.close();

      if (_cancelToken?.isCancelled != true) {
        // Mark as complete in preferences.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefKeyIsModelReady, true);
        await prefs.setString(_prefKeyModelPath, filePath);
        _stopNotificationUpdates();
        await DownloadNotificationService.instance.showCompleted(
          title: '${variant.displayName} ready',
          body: 'Your offline AI model finished downloading.',
        );
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        // User-initiated cancel — not an error.
        _stopNotificationUpdates();
        await DownloadNotificationService.instance.cancel();
        return;
      }
      _stopNotificationUpdates();
      await DownloadNotificationService.instance.cancel();
      onError?.call(e);
    } finally {
      await WakelockPlus.disable();
      _stopNotificationUpdates();
      _cancelToken = null;
    }
  }

  /// Cancels an in-progress download.
  void cancelDownload() {
    _cancelToken?.cancel('User cancelled');
  }

  void _startNotificationUpdates(
    ModelVariant variant,
    DownloadProgress progress,
  ) {
    _activeNotificationVariant = variant;
    _latestNotificationProgress = progress;
    _notificationTimer?.cancel();

    unawaited(_publishLatestNotification());
    _notificationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_publishLatestNotification());
    });
  }

  Future<void> _publishLatestNotification() async {
    final variant = _activeNotificationVariant;
    final progress = _latestNotificationProgress;
    if (variant == null || progress == null) return;

    final percent = (progress.fraction * 100).floor().clamp(0, 100);
    await DownloadNotificationService.instance.showProgress(
      title: 'Downloading ${variant.displayName}',
      body: 'Downloaded ${progress.receivedLabel} / ${progress.totalLabel}',
      progress: percent,
    );
  }

  void _stopNotificationUpdates() {
    _notificationTimer?.cancel();
    _notificationTimer = null;
    _activeNotificationVariant = null;
    _latestNotificationProgress = null;
    _downloadStartedAt = null;
    _downloadStartBytes = 0;
  }

  Duration? _estimateRemainingTime({
    required int receivedBytes,
    required int totalBytes,
  }) {
    final startedAt = _downloadStartedAt;
    if (startedAt == null || receivedBytes >= totalBytes) {
      return Duration.zero;
    }

    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed.inSeconds < 3) {
      return null;
    }

    final downloadedThisSession = receivedBytes - _downloadStartBytes;
    if (downloadedThisSession <= 0) {
      return null;
    }

    final bytesPerSecond = downloadedThisSession / elapsed.inSeconds;
    if (bytesPerSecond <= 0) {
      return null;
    }

    final remainingBytes = totalBytes - receivedBytes;
    final remainingSeconds = (remainingBytes / bytesPerSecond).round();
    if (remainingSeconds <= 0) {
      return Duration.zero;
    }

    return Duration(seconds: remainingSeconds);
  }
}
