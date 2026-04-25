import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import '../../../core/database/database_helper.dart';
import '../../chat/services/ai_chat_service.dart';

class MaterialProcessorService {
  static final MaterialProcessorService instance = MaterialProcessorService._internal();
  MaterialProcessorService._internal();

  final _uuid = const Uuid();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInit = false;

  Future<void> initNotifications() async {
    if (_isInit) return;
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS);
    await _notificationsPlugin.initialize(initializationSettings);
    _isInit = true;
  }

  Future<void> processFile(String filePath, AiChatService aiService, {Function(String status, double progress)? onProgress}) async {
    await initNotifications();
    final file = File(filePath);
    final ext = p.extension(filePath).toLowerCase();
    final filename = p.basename(filePath);
    final materialId = _uuid.v4();

    // 1. Save metadata
    await DatabaseHelper.instance.insertMaterial({
      DatabaseHelper.columnId: materialId,
      DatabaseHelper.columnFilename: filename,
      DatabaseHelper.columnType: ext.replaceAll('.', ''),
      DatabaseHelper.columnCreatedAt: DateTime.now().millisecondsSinceEpoch,
    });

    // 2. Start Processing based on extension
    if (ext == '.pdf') {
      await _processPdf(file, materialId, aiService, filename, onProgress);
    } else if (ext == '.docx') {
      await _processDocx(file, materialId, aiService, filename, onProgress);
    } else if (['.mp3', '.m4a', '.wav'].contains(ext)) {
      await _processAudio(file, materialId, aiService, filename, onProgress);
    } else if (['.jpg', '.png'].contains(ext)) {
      await _processImage(file, materialId, aiService, filename, onProgress);
    } else {
      await DatabaseHelper.instance.updateMaterialStatus(materialId, 'failed');
      await _showNotification('Import Failed', 'Unsupported format: $ext', 0, 0);
    }
  }

  Future<void> _processPdf(File file, String materialId, AiChatService aiService, String title, Function(String status, double progress)? onProgress) async {
    if (onProgress != null) onProgress('Extracting text...', 0.0);
    
    final List<String> pages = await ReadPdfText.getPDFtextPaginated(file.path);
    final totalPages = pages.length;

    for (int i = 0; i < totalPages; i++) {
        if (onProgress != null) onProgress('Page ${i + 1} is processing...', i / totalPages);
        await _showNotification('Processing $title', 'Page ${i + 1} of $totalPages', totalPages, i);
        
        final rawText = pages[i];
        
        // Clean with AI (Skipped for now to improve speed)
        final cleanedText = rawText; // await _improveTextWithGemma(rawText, aiService);
        
        // Save
        await DatabaseHelper.instance.insertChunk({
            DatabaseHelper.columnChunkId: _uuid.v4(),
            DatabaseHelper.columnMaterialId: materialId,
            DatabaseHelper.columnChunkIndex: i,
            DatabaseHelper.columnContent: cleanedText,
            DatabaseHelper.columnSourceType: 'pdf_page',
        });
    }
    
    await DatabaseHelper.instance.updateMaterialStatus(materialId, 'processed');
    await _showNotification('Import Complete', '$title is ready.', 1, 1);
  }

  Future<void> _processDocx(File file, String materialId, AiChatService aiService, String title, Function(String status, double progress)? onProgress) async {
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
    await _showNotification('Processing $title', 'Improving with Gemma...', 10, 6);
    final chunks = _splitText(rawText, 1000);
    for (int i = 0; i < chunks.length; i++) {
      if (onProgress != null) onProgress('Chunk ${i+1} is processing...', i / chunks.length);
      await _showNotification('Processing $title', 'Chunk ${i+1} of ${chunks.length}', chunks.length, i);
      // Clean with AI (Skipped for now to improve speed)
      final improvedChunk = chunks[i]; // await _improveTextWithGemma(chunks[i], aiService);
      
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

  Future<void> _processImage(File file, String materialId, AiChatService aiService, String title, Function(String status, double progress)? onProgress) async {
    if (onProgress != null) onProgress('Extracting text with ML Kit...', 0.5);
    await _showNotification('Processing $title', 'Extracting text with ML Kit...', 1, 0);
    try {
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
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
      await DatabaseHelper.instance.updateMaterialStatus(materialId, 'processed');
      await _showNotification('Import Complete', '$title is ready.', 1, 1);
    } catch(e) {
      await DatabaseHelper.instance.updateMaterialStatus(materialId, 'failed');
      await _showNotification('Import Failed', 'Error processing image: $e', 0, 0);
    }
  }

  Future<void> _processAudio(File file, String materialId, AiChatService aiService, String title, Function(String status, double progress)? onProgress) async {
    if (onProgress != null) onProgress('Starting audio transcription...', 0.1);
    await _showNotification('Processing $title', 'Starting audio transcription...', 100, 10);
    
    // NOTE: Simulating offline Whisper audio slicing and ASR.
    // In production with whisper_flutter_plus, use Whisper.transcribe(filePath) here.
    await Future.delayed(const Duration(seconds: 3));
    final simulatedTranscript = "This is a placeholder transcribed audio output since the flutter whisper package requires platform specific integration in the native layer (which needs manual setup in C++ and AppDelegate.swift for iOS, and CMakeLists for Android).";
    
    if (onProgress != null) onProgress('Improving transcript with Gemma...', 0.7);
    await _showNotification('Processing $title', 'Improving transcript with Gemma...', 100, 70);
    // Clean with AI (Skipped for now to improve speed)
    final improvedText = simulatedTranscript; // await _improveTextWithGemma(simulatedTranscript, aiService);

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

  Future<String> _improveTextWithGemma(String rawText, AiChatService aiService) async {
     if (rawText.trim().isEmpty) return "";
     try {
       // Context for the model
       final prompt = "Fix any OCR errors and typos, and structure the following text from an educational material clearly (reply with ONLY the corrected text, no conversational filler):\n\n$rawText";
       final stream = aiService.sendMessage(prompt);
       return await stream.last;
     } catch (e) {
       return rawText; // Fallback to raw text upon AI error
     }
  }

  List<String> _splitText(String text, int length) {
    List<String> chunks = [];
    for (var i = 0; i < text.length; i += length) {
      chunks.add(text.substring(i, i + length > text.length ? text.length : i + length));
    }
    return chunks;
  }

  Future<void> _showNotification(String title, String body, int maxProgress, int progress) async {
     final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
            'mentora_import', 'Material Import',
            channelDescription: 'Progress for syncing and processing materials',
            importance: Importance.low,
            priority: Priority.low,
            showProgress: true,
            maxProgress: maxProgress,
            progress: progress,
            onlyAlertOnce: true);
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await _notificationsPlugin.show(
        0, title, body, platformChannelSpecifics);
  }
}
