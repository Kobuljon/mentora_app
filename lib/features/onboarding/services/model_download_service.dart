import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/services/download_notification_service.dart';

enum ModelVariant { e2b, e4b, e2bMultimodal }

extension ModelVariantExtension on ModelVariant {
  String get url => switch (this) {
    ModelVariant.e2b =>
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
    ModelVariant.e4b =>
      'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm',
    ModelVariant.e2bMultimodal =>
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
  };

  String get fileName => switch (this) {
    ModelVariant.e2b => 'gemma-4-E2B-it.litertlm',
    ModelVariant.e4b => 'gemma-4-E4B-it.litertlm',
    ModelVariant.e2bMultimodal => 'gemma-4-E2B-it-multimodal.litertlm',
  };

  String get displayName => switch (this) {
    ModelVariant.e2b => 'Standard Engine (Gemma 4 E2B)',
    ModelVariant.e4b => 'Advanced Engine (Gemma 4 E4B)',
    ModelVariant.e2bMultimodal => 'Multimodal Engine (Gemma 4 E2B + Vision)',
  };

  String get shortLabel => switch (this) {
    ModelVariant.e2b => 'Gemma 4 E2B',
    ModelVariant.e4b => 'Gemma 4 E4B',
    ModelVariant.e2bMultimodal => 'Gemma 4 E2B Vision',
  };

  String get description => switch (this) {
    ModelVariant.e2b => 'Text-only model. Fast and lightweight.',
    ModelVariant.e4b => 'Larger text-only model with better reasoning.',
    ModelVariant.e2bMultimodal =>
      'Supports text and image input. Required for image upload features.',
  };

  /// Approximate size in bytes used for disk space pre-check.
  int get approximateSizeBytes => switch (this) {
    ModelVariant.e2b => 2 * 1024 * 1024 * 1024, // ~2 GB
    ModelVariant.e4b => 4 * 1024 * 1024 * 1024, // ~4 GB
    ModelVariant.e2bMultimodal => 3 * 1024 * 1024 * 1024, // ~3 GB
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

class DownloadedModelInfo {
  const DownloadedModelInfo({
    required this.variant,
    required this.path,
    required this.sizeBytes,
  });

  final ModelVariant variant;
  final String path;
  final int sizeBytes;

  String get sizeLabel {
    const units = ['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double value = sizeBytes.toDouble();
    while (value >= 1024 && i < units.length - 1) {
      value /= 1024;
      i++;
    }
    return '${value.toStringAsFixed(1)} ${units[i]}';
  }
}

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
    final path = prefs.getString(_prefKeyModelPath);
    if (isReady && path != null && File(path).existsSync()) {
      return true;
    }

    // If preferences were reset but model files still exist, recover automatically.
    final recoveredPath = await _recoverReadyModelPath();
    if (recoveredPath == null) {
      await prefs.remove(_prefKeyIsModelReady);
      await prefs.remove(_prefKeyModelPath);
      return false;
    }

    await _markModelReady(recoveredPath);
    return true;
  }

  /// Returns the exact local path of the downloaded model file.
  ///
  /// Throws if no fully-downloaded model is currently available.
  Future<String> getReadyModelPath() async {
    final prefs = await SharedPreferences.getInstance();
    final storedPath = prefs.getString(_prefKeyModelPath);
    final path =
        (storedPath != null &&
            storedPath.isNotEmpty &&
            File(storedPath).existsSync())
        ? storedPath
        : await _recoverReadyModelPath();

    if (path == null || path.isEmpty) {
      throw StateError('No downloaded model path is available.');
    }

    if (!File(path).existsSync()) {
      throw StateError('Downloaded model file was not found at $path.');
    }

    return path;
  }

  Future<DownloadedModelInfo?> getActiveModel() async {
    final path = await getReadyModelPath();
    for (final variant in ModelVariant.values) {
      final variantPath = await _getModelFilePath(variant);
      if (variantPath == path) {
        return getDownloadedModel(variant);
      }
    }

    final file = File(path);
    if (!await file.exists()) return null;
    return DownloadedModelInfo(
      variant: ModelVariant.e2b,
      path: path,
      sizeBytes: await file.length(),
    );
  }

  Future<void> setActiveModel(DownloadedModelInfo model) async {
    final file = File(model.path);
    if (!await file.exists()) {
      throw StateError('Model file was not found at ${model.path}.');
    }
    await _markModelReady(model.path);
  }

  Future<String?> _recoverReadyModelPath() async {
    // First try known variant filenames in the app documents directory.
    for (final variant in ModelVariant.values) {
      final variantPath = await _getModelFilePath(variant);
      final file = File(variantPath);
      if (await file.exists()) {
        return variantPath;
      }
    }

    // Fallback: pick the largest .litertlm file if one exists.
    final dir = await getApplicationDocumentsDirectory();
    final litertFiles = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && _isLiteRtLmFile(entity.path)) {
        litertFiles.add(entity);
      }
    }

    if (litertFiles.isEmpty) return null;

    File best = litertFiles.first;
    int bestSize = await best.length();
    for (final file in litertFiles.skip(1)) {
      final size = await file.length();
      if (size > bestSize) {
        best = file;
        bestSize = size;
      }
    }

    return best.path;
  }

  Future<String> _getModelFilePath(ModelVariant variant) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/${variant.fileName}';
  }

  Future<void> _markModelReady(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyIsModelReady, true);
    await prefs.setString(_prefKeyModelPath, filePath);
  }

  bool _isLiteRtLmFile(String fileName) {
    return fileName.toLowerCase().endsWith('.litertlm');
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
        await _markModelReady(filePath);
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

  /// Returns info about all downloaded model variants.
  Future<List<DownloadedModelInfo>> getDownloadedModels() async {
    final results = <DownloadedModelInfo>[];
    for (final variant in ModelVariant.values) {
      final info = await getDownloadedModel(variant);
      if (info != null) {
        results.add(info);
      }
    }
    return results;
  }

  Future<DownloadedModelInfo?> getDownloadedModel(ModelVariant variant) async {
    final path = await _getModelFilePath(variant);
    final file = File(path);
    if (!await file.exists()) return null;

    return DownloadedModelInfo(
      variant: variant,
      path: path,
      sizeBytes: await file.length(),
    );
  }

  Future<DownloadedModelInfo> importModelFile({
    required ModelVariant variant,
    required String fileName,
    required Stream<List<int>> bytes,
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    if (!_isLiteRtLmFile(fileName)) {
      throw const FormatException('Only .litertlm model files are supported.');
    }

    final destinationPath = await _getModelFilePath(variant);
    final destination = File(destinationPath);
    await destination.parent.create(recursive: true);

    IOSink? sink;
    var writtenBytes = 0;
    try {
      if (await destination.exists()) {
        await destination.delete();
      }

      sink = destination.openWrite(mode: FileMode.write);
      await for (final chunk in bytes) {
        sink.add(chunk);
        writtenBytes += chunk.length;
        onProgress?.call(DownloadProgress(received: writtenBytes, total: 0));
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (writtenBytes == 0) {
        await destination.delete();
        throw const FormatException('The selected model file is empty.');
      }

      await _markModelReady(destinationPath);
      return DownloadedModelInfo(
        variant: variant,
        path: destinationPath,
        sizeBytes: writtenBytes,
      );
    } catch (_) {
      await sink?.close();
      if (await destination.exists()) {
        await destination.delete();
      }
      rethrow;
    }
  }

  Future<String> exportModelToDirectory({
    required DownloadedModelInfo model,
    required String directoryPath,
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    final source = File(model.path);
    if (!await source.exists()) {
      throw StateError('Model file was not found at ${model.path}.');
    }

    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      throw StateError('Export folder was not found.');
    }

    final destinationPath = '${directory.path}/${model.variant.fileName}';
    final destination = File(destinationPath);
    IOSink? sink;
    var writtenBytes = 0;

    try {
      if (await destination.exists()) {
        await destination.delete();
      }

      sink = destination.openWrite(mode: FileMode.write);
      await for (final chunk in source.openRead()) {
        sink.add(chunk);
        writtenBytes += chunk.length;
        onProgress?.call(
          DownloadProgress(received: writtenBytes, total: model.sizeBytes),
        );
      }
      await sink.flush();
      await sink.close();
      sink = null;
      return destinationPath;
    } catch (_) {
      await sink?.close();
      if (await destination.exists()) {
        await destination.delete();
      }
      rethrow;
    }
  }

  /// Deletes the downloaded file for [variant] and clears prefs if it was the active model.
  Future<void> deleteModel(ModelVariant variant) async {
    final path = await _getModelFilePath(variant);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString(_prefKeyModelPath);
    if (savedPath == path) {
      await prefs.remove(_prefKeyIsModelReady);
      await prefs.remove(_prefKeyModelPath);
    }
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
