import 'dart:async';
import 'dart:isolate';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audio_decoder/audio_decoder.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../../core/services/sherpa_onnx_model_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../core/database/database_helper.dart';
import '../../settings/providers/settings_provider.dart';

class MaterialProcessorService {
  static final MaterialProcessorService instance =
      MaterialProcessorService._internal();
  MaterialProcessorService._internal();

  final _uuid = const Uuid();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInit = false;
  static final _wordPattern = RegExp(r"[A-Za-z][A-Za-z'-]{2,}");
  static final _symbolPattern = RegExp(r'''[^A-Za-z0-9\s.,;:!?'"()\-/]''');
  static final _vowelPattern = RegExp(r'[aeiou]', caseSensitive: false);

  Future<void> initNotifications() async {
    if (_isInit) return;
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
    await _notificationsPlugin.initialize(initializationSettings);
    _isInit = true;
  }

  Future<void> processFile(
    String filePath, {
    String? displayName,
    Function(String status, double progress)? onProgress,
  }) async {
    await initNotifications();
    final file = File(filePath);
    final ext = p.extension(filePath).toLowerCase();
    final originalFilename = p.basename(filePath);
    final title = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : originalFilename;
    final materialId = _uuid.v4();

    // 1. Save metadata
    await DatabaseHelper.instance.insertMaterial({
      DatabaseHelper.columnId: materialId,
      DatabaseHelper.columnFilename: title,
      DatabaseHelper.columnType: ext.replaceAll('.', ''),
      DatabaseHelper.columnCreatedAt: DateTime.now().millisecondsSinceEpoch,
    });

    try {
      // 2. Start Processing based on extension
      if (ext == '.pdf') {
        await _processPdf(file, materialId, title, onProgress);
      } else if (ext == '.docx') {
        await _processDocx(file, materialId, title, onProgress);
      } else if (['.mp3', '.m4a', '.wav'].contains(ext)) {
        await _processAudio(file, materialId, title, onProgress);
      } else if (['.jpg', '.png'].contains(ext)) {
        await _processImage(file, materialId, title, onProgress);
      } else {
        await DatabaseHelper.instance.updateMaterialStatus(
          materialId,
          'failed',
        );
        await _showNotification(
          'Import Failed',
          'Unsupported format: $ext',
          0,
          0,
        );
      }
    } catch (error) {
      await DatabaseHelper.instance.updateMaterialStatus(materialId, 'failed');
      await _showNotification(
        'Import Failed',
        'Could not process $title. Please try again.',
        0,
        0,
      );
      rethrow;
    }
  }

  Future<void> _processPdf(
    File file,
    String materialId,
    String title,
    Function(String status, double progress)? onProgress,
  ) async {
    if (onProgress != null) onProgress('Opening PDF...', 0.02);

    PdfDocument? document;
    PdfTextExtractor? extractor;
    var savedChunks = 0;
    var skippedPages = 0;
    final stopwatch = Stopwatch()..start();

    try {
      document = PdfDocument(inputBytes: await file.readAsBytes());
      extractor = PdfTextExtractor(document);
      final totalPages = document.pages.count;
      if (totalPages == 0) {
        await DatabaseHelper.instance.updateMaterialStatus(
          materialId,
          'failed',
        );
        await _showNotification(
          'Import Failed',
          'The selected PDF has no pages.',
          1,
          1,
        );
        return;
      }

      for (int i = 0; i < totalPages; i++) {
        final pageNumber = i + 1;
        final pageProgress = pageNumber / totalPages;
        if (onProgress != null) {
          onProgress(
            'Extracted $pageNumber/$totalPages pages (saved: $savedChunks, skipped: $skippedPages)',
            0.05 + (pageProgress * 0.9),
          );
        }
        await _showNotification(
          'Processing $title',
          'Extracted $pageNumber/$totalPages pages',
          totalPages,
          pageNumber,
        );

        final rawText = extractor.extractText(
          startPageIndex: i,
          endPageIndex: i,
        );
        var cleanedText = _cleanExtractedText(rawText);

        if (!_isUsableTrainingText(cleanedText)) {
          skippedPages++;
          continue;
        }

        await DatabaseHelper.instance.insertChunk({
          DatabaseHelper.columnChunkId: _uuid.v4(),
          DatabaseHelper.columnMaterialId: materialId,
          DatabaseHelper.columnChunkIndex: i,
          DatabaseHelper.columnPageNumber: pageNumber,
          DatabaseHelper.columnContent: cleanedText,
          DatabaseHelper.columnSourceType: 'pdf_page',
        });
        savedChunks++;
      }
    } finally {
      document?.dispose();
      stopwatch.stop();
    }

    if (savedChunks == 0) {
      await DatabaseHelper.instance.updateMaterialStatus(materialId, 'failed');
      await _showNotification(
        'Import Failed',
        'No readable text found in $title.',
        1,
        1,
      );
      return;
    }

    await DatabaseHelper.instance.updateMaterialStatus(materialId, 'processed');
    final skippedSuffix = skippedPages > 0
        ? ' Skipped $skippedPages noisy pages.'
        : '';
    final elapsedSeconds = stopwatch.elapsed.inSeconds;
    await _showNotification(
      'Import Complete',
      '$title is ready in ${elapsedSeconds}s.$skippedSuffix',
      1,
      1,
    );
  }

  Future<void> _processDocx(
    File file,
    String materialId,
    String title,
    Function(String status, double progress)? onProgress,
  ) async {
    if (onProgress != null) onProgress('Extracting XML...', 0.1);
    await _showNotification('Processing $title', 'Extracting XML...', 10, 2);
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    String rawText = '';
    for (final archiveFile in archive) {
      if (archiveFile.name == 'word/document.xml') {
        final content = archiveFile.content as List<int>;
        final xmlString = String.fromCharCodes(content);
        // XML text extraction regex
        final regExp = RegExp(r'<w:t(?:[^>]*)>(.*?)<\/w:t>');
        final matches = regExp.allMatches(xmlString);
        for (final match in matches) {
          rawText += '${match.group(1)} ';
        }
        break;
      }
    }

    if (onProgress != null) onProgress('Improving with Gemma...', 0.6);
    await _showNotification(
      'Processing $title',
      'Improving with Gemma...',
      10,
      6,
    );
    final chunks = _splitText(rawText, 1000);
    for (int i = 0; i < chunks.length; i++) {
      if (onProgress != null) {
        onProgress('Chunk ${i + 1} is processing...', i / chunks.length);
      }
      await _showNotification(
        'Processing $title',
        'Chunk ${i + 1} of ${chunks.length}',
        chunks.length,
        i,
      );
      // Clean with AI (Skipped for now to improve speed)
      final improvedChunk =
          chunks[i]; // await _improveTextWithGemma(chunks[i], aiService);

      await DatabaseHelper.instance.insertChunk({
        DatabaseHelper.columnChunkId: _uuid.v4(),
        DatabaseHelper.columnMaterialId: materialId,
        DatabaseHelper.columnChunkIndex: i,
        DatabaseHelper.columnContent: improvedChunk,
        DatabaseHelper.columnSourceType: 'docx_text',
      });
    }
    await DatabaseHelper.instance.updateMaterialStatus(materialId, 'processed');
    await _showNotification('Import Complete', '$title is ready.', 1, 1);
  }

  Future<void> _processImage(
    File file,
    String materialId,
    String title,
    Function(String status, double progress)? onProgress,
  ) async {
    if (onProgress != null) onProgress('Extracting text with ML Kit...', 0.5);
    await _showNotification(
      'Processing $title',
      'Extracting text with ML Kit...',
      1,
      0,
    );
    try {
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final inputImage = InputImage.fromFilePath(file.path);
      final recognizedText = await textRecognizer.processImage(inputImage);
      textRecognizer.close();

      await DatabaseHelper.instance.insertChunk({
        DatabaseHelper.columnChunkId: _uuid.v4(),
        DatabaseHelper.columnMaterialId: materialId,
        DatabaseHelper.columnChunkIndex: 0,
        DatabaseHelper.columnContent: recognizedText.text,
        DatabaseHelper.columnSourceType: 'image',
      });
      await DatabaseHelper.instance.updateMaterialStatus(
        materialId,
        'processed',
      );
      await _showNotification('Import Complete', '$title is ready.', 1, 1);
    } catch (e) {
      await DatabaseHelper.instance.updateMaterialStatus(materialId, 'failed');
      await _showNotification(
        'Import Failed',
        'Error processing image: $e',
        0,
        0,
      );
    }
  }

  Future<void> _processAudio(
    File file,
    String materialId,
    String title,
    Function(String status, double progress)? onProgress,
  ) async {
    if (onProgress != null) onProgress('Starting audio transcription...', 0.1);
    await _showNotification(
      'Processing $title',
      'Starting audio transcription...',
      100,
      10,
    );

    final backend = await _getAudioBackend();
    String transcript;
    File? sherpaInputFile;
    Timer? transcriptionProgressTimer;

    if (backend == AudioTranscriptionBackend.sherpaOnnx) {
      try {
        if (onProgress != null) {
          onProgress('Preparing audio for Sherpa ONNX...', 0.35);
        }
        await _showNotification(
          'Processing $title',
          'Preparing audio for Sherpa ONNX...',
          100,
          35,
        );
        final conversionTimeout = await _audioConversionTimeout(file);
        sherpaInputFile = await _prepareAudioForSherpa(file).timeout(
          conversionTimeout,
          onTimeout: () {
            throw TimeoutException(
              'Audio conversion exceeded ${_formatDuration(conversionTimeout)}. Try WAV format or a shorter audio file.',
            );
          },
        );

        if (onProgress != null) {
          onProgress('Transcribing with Sherpa ONNX...', 0.6);
        }
        await _showNotification(
          'Processing $title',
          'Transcribing with Sherpa ONNX...',
          100,
          60,
        );
        if (onProgress != null) {
          var displayedProgress = 0.6;
          transcriptionProgressTimer = Timer.periodic(
            const Duration(milliseconds: 900),
            (_) {
              displayedProgress = math.min(0.88, displayedProgress + 0.02);
              onProgress(
                'Transcribing with Sherpa ONNX... this can take a while for long audio.',
                displayedProgress,
              );
            },
          );
        }
        final transcriptionTimeout = await _audioTranscriptionTimeout(file);
        transcript = await _transcribeAudioWithSherpaOnnx(sherpaInputFile).timeout(
          transcriptionTimeout,
          onTimeout: () {
            throw TimeoutException(
              'Audio transcription exceeded ${_formatDuration(transcriptionTimeout)}. Try a shorter clip.',
            );
          },
        );
      } catch (error) {
        throw Exception('Sherpa ONNX failed: $error');
      } finally {
        transcriptionProgressTimer?.cancel();
        if (sherpaInputFile != null && sherpaInputFile.path != file.path) {
          final tempFile = sherpaInputFile;
          if (tempFile.existsSync()) {
            await tempFile.delete();
          }
        }
      }
    } else {
      transcript = await _buildPlaceholderAudioTranscript(file, null);
    }

    if (onProgress != null) {
      onProgress('Finalizing transcript...', 0.9);
    }
    await _showNotification(
      'Processing $title',
      'Finalizing transcript...',
      100,
      90,
    );
    final improvedText = transcript;

    await DatabaseHelper.instance.insertChunk({
      DatabaseHelper.columnChunkId: _uuid.v4(),
      DatabaseHelper.columnMaterialId: materialId,
      DatabaseHelper.columnChunkIndex: 0,
      DatabaseHelper.columnContent: improvedText,
      DatabaseHelper.columnSourceType: 'audio',
    });

    await DatabaseHelper.instance.updateMaterialStatus(materialId, 'processed');
    await _showNotification('Import Complete', '$title is ready.', 1, 1);
  }

  Future<File> _prepareAudioForSherpa(File file) async {
    final extension = p.extension(file.path).toLowerCase();
    if (extension == '.wav' || extension == '.wave') {
      return file;
    }

    if (!AudioDecoder.needsConversion(file.path)) {
      throw UnsupportedError(
        'Sherpa ONNX needs a WAV file, and ${p.basename(file.path)} is not in a supported conversion format.',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final outputDirectory = Directory(
      p.join(tempDir.path, 'mentora_sherpa_audio'),
    );
    if (!outputDirectory.existsSync()) {
      await outputDirectory.create(recursive: true);
    }

    final wavPath = p.join(
      outputDirectory.path,
      '${p.basenameWithoutExtension(file.path)}_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    await AudioDecoder.convertToWav(
      file.path,
      wavPath,
      sampleRate: 16000,
      channels: 1,
      bitDepth: 16,
    );

    return File(wavPath);
  }

  Future<Duration> _audioConversionTimeout(File file) async {
    final duration = await _readAudioDuration(file);
    if (duration != null) {
      return _clampDuration(
        _scaleDuration(duration, 2),
        min: const Duration(minutes: 10),
        max: const Duration(minutes: 45),
      );
    }

    final sizeMegabytes = await _fileSizeMegabytes(file);
    return _clampDuration(
      Duration(minutes: sizeMegabytes.ceil() * 3),
      min: const Duration(minutes: 10),
      max: const Duration(minutes: 45),
    );
  }

  Future<Duration> _audioTranscriptionTimeout(File file) async {
    final duration = await _readAudioDuration(file);
    if (duration != null) {
      return _clampDuration(
        _scaleDuration(duration, 6),
        min: const Duration(minutes: 15),
        max: const Duration(minutes: 90),
      );
    }

    final sizeMegabytes = await _fileSizeMegabytes(file);
    return _clampDuration(
      Duration(minutes: sizeMegabytes.ceil() * 6),
      min: const Duration(minutes: 15),
      max: const Duration(minutes: 90),
    );
  }

  Future<Duration?> _readAudioDuration(File file) async {
    try {
      final info = await AudioDecoder.getAudioInfo(
        file.path,
      ).timeout(const Duration(seconds: 8));
      return info.duration > Duration.zero ? info.duration : null;
    } catch (_) {
      return null;
    }
  }

  Future<double> _fileSizeMegabytes(File file) async {
    try {
      return await file.length() / (1024 * 1024);
    } catch (_) {
      return 1;
    }
  }

  Duration _scaleDuration(Duration duration, int multiplier) {
    return Duration(microseconds: duration.inMicroseconds * multiplier);
  }

  Duration _clampDuration(
    Duration duration, {
    required Duration min,
    required Duration max,
  }) {
    if (duration < min) return min;
    if (duration > max) return max;
    return duration;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    if (seconds == 0) {
      return '$minutes minutes';
    }
    return '$minutes minutes $seconds seconds';
  }

  Future<AudioTranscriptionBackend> _getAudioBackend() async {
    final preferences = await SharedPreferences.getInstance();
    final backendName = preferences.getString(
      audioTranscriptionBackendPreferenceKey,
    );
    final modelStatus = await SherpaOnnxModelService.instance.getStatus();
    if (modelStatus.isReady) {
      return AudioTranscriptionBackend.sherpaOnnx;
    }

    for (final backend in AudioTranscriptionBackend.values) {
      if (backend.name == backendName &&
          backend != AudioTranscriptionBackend.placeholder) {
        return backend;
      }
    }
    return AudioTranscriptionBackend.sherpaOnnx;
  }

  Future<String> _transcribeAudioWithSherpaOnnx(File file) async {
    final modelStatus = await SherpaOnnxModelService.instance.getStatus();
    if (!modelStatus.isReady) {
      throw FileSystemException(
        'Missing Sherpa ONNX model files: ${modelStatus.missingFiles.join(', ')}. Expected in ${modelStatus.rootPath}',
      );
    }

    final encoderPath = SherpaOnnxModelService.instance.filePathFor(
      modelStatus.rootPath,
      SherpaOnnxModelService.encoderFileName,
    );
    final decoderPath = SherpaOnnxModelService.instance.filePathFor(
      modelStatus.rootPath,
      SherpaOnnxModelService.decoderFileName,
    );
    final tokensPath = SherpaOnnxModelService.instance.filePathFor(
      modelStatus.rootPath,
      SherpaOnnxModelService.tokensFileName,
    );

    return Isolate.run(
      () => _runSherpaTranscription(
        _SherpaTranscriptionRequest(
          audioFilePath: file.path,
          encoderPath: encoderPath,
          decoderPath: decoderPath,
          tokensPath: tokensPath,
        ),
      ),
    );
  }
}

class _SherpaTranscriptionRequest {
  const _SherpaTranscriptionRequest({
    required this.audioFilePath,
    required this.encoderPath,
    required this.decoderPath,
    required this.tokensPath,
  });

  final String audioFilePath;
  final String encoderPath;
  final String decoderPath;
  final String tokensPath;
}

String _runSherpaTranscription(_SherpaTranscriptionRequest request) {
  sherpa.initBindings();

  final whisperConfig = sherpa.OfflineWhisperModelConfig(
    encoder: request.encoderPath,
    decoder: request.decoderPath,
    language: 'en',
    task: 'transcribe',
  );
  final modelConfig = sherpa.OfflineModelConfig(
    whisper: whisperConfig,
    tokens: request.tokensPath,
    modelType: 'whisper',
    numThreads: 2,
    debug: false,
  );
  final recognizer = sherpa.OfflineRecognizer(
    sherpa.OfflineRecognizerConfig(model: modelConfig),
  );

  sherpa.OfflineStream? stream;
  try {
    final wave = sherpa.readWave(request.audioFilePath);
    if (wave.sampleRate <= 0 || wave.samples.isEmpty) {
      throw const FormatException(
        'Could not decode WAV file for Sherpa ONNX transcription.',
      );
    }

    final chunkTexts = <String>[];
    final chunkDurationSeconds = 20;
    final samplesPerChunk = wave.sampleRate * chunkDurationSeconds;

    for (var start = 0; start < wave.samples.length; start += samplesPerChunk) {
      final end = math.min(start + samplesPerChunk, wave.samples.length);
      final chunkSamples = Float32List.sublistView(wave.samples, start, end);

      stream = recognizer.createStream();
      stream.acceptWaveform(samples: chunkSamples, sampleRate: wave.sampleRate);
      recognizer.decode(stream);

      final text = recognizer.getResult(stream).text.trim();
      if (text.isNotEmpty) {
        chunkTexts.add(text);
      }

      stream.free();
      stream = null;
    }

    final text = chunkTexts.join(' ').trim();
    if (text.isEmpty) {
      throw const FormatException('Sherpa ONNX returned an empty transcript.');
    }
    return text;
  } finally {
    stream?.free();
    recognizer.free();
  }
}

extension _MaterialProcessorServiceTextUtils on MaterialProcessorService {
  Future<String> _buildPlaceholderAudioTranscript(
    File file,
    Object? failure,
  ) async {
    await Future.delayed(const Duration(seconds: 2));
    final reason = failure == null
        ? 'Audio backend is set to placeholder mode.'
        : 'Sherpa ONNX failed: $failure';
    return 'Audio transcript placeholder for ${p.basename(file.path)}. $reason';
  }

  List<String> _splitText(String text, int length) {
    List<String> chunks = [];
    for (var i = 0; i < text.length; i += length) {
      chunks.add(
        text.substring(i, i + length > text.length ? text.length : i + length),
      );
    }
    return chunks;
  }

  String _cleanExtractedText(String text) {
    final lines = text
        .replaceAll('\u0000', ' ')
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .where((line) => !_looksLikeExtractionNoise(line))
        .toList();
    return lines.join('\n').trim();
  }

  bool _isUsableTrainingText(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length < 80) return false;
    return _textQualityScore(compact) >= 18;
  }

  double _textQualityScore(String text) {
    final words = MaterialProcessorService._wordPattern.allMatches(text).length;
    final letters = RegExp(r'[A-Za-z]').allMatches(text).length;
    final symbols = MaterialProcessorService._symbolPattern
        .allMatches(text)
        .length;
    final total = text.trim().length;
    if (total == 0) return 0;
    final letterRatio = letters / total;
    final symbolRatio = symbols / total;
    return words + (letterRatio * 24) - (symbolRatio * 36);
  }

  bool _looksLikeExtractionNoise(String line) {
    if (line.length < 3) return false;

    final letters = RegExp(r'[A-Za-z]').allMatches(line).length;
    final words = MaterialProcessorService._wordPattern.allMatches(line).length;
    final symbols = MaterialProcessorService._symbolPattern
        .allMatches(line)
        .length;
    final total = line.length;
    final letterRatio = letters / total;
    final symbolRatio = symbols / total;

    if (words == 0 && total > 12) return true;
    if (symbolRatio > 0.22 && letterRatio < 0.62) return true;

    if (letters >= 12) {
      final vowels = MaterialProcessorService._vowelPattern
          .allMatches(line)
          .length;
      if (vowels / letters < 0.18 && symbolRatio > 0.12) return true;
    }

    final punctuationRuns = RegExp(
      r'''[%$*+=_\\|@#~`^]{2,}''',
    ).allMatches(line).length;
    return punctuationRuns >= 2 && words < 4;
  }

  Future<void> _showNotification(
    String title,
    String body,
    int maxProgress,
    int progress,
  ) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'mentora_import',
          'Material Import',
          channelDescription: 'Progress for syncing and processing materials',
          importance: Importance.low,
          priority: Priority.low,
          showProgress: true,
          maxProgress: maxProgress,
          progress: progress,
          onlyAlertOnce: true,
        );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await _notificationsPlugin.show(0, title, body, platformChannelSpecifics);
  }
}
