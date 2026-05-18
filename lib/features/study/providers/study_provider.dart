import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_helper.dart';
import '../../settings/providers/settings_provider.dart';
import '../services/ai_study_service.dart';

final aiStudyServiceProvider = Provider<AiStudyService>((ref) {
  final settings = ref.watch(settingsProvider);
  final service = AiStudyService(settings);
  ref.onDispose(() => service.dispose());
  return service;
});

final studyProvider = StateNotifierProvider<StudyNotifier, StudyState>((ref) {
  return StudyNotifier(ref.watch(aiStudyServiceProvider));
});

const _sentinel = Object();

class StudyState {
  final bool isGenerating;
  final String? generatingProgress;
  final String? error;
  final List<Map<String, dynamic>> bundles;
  final Map<String, List<Map<String, dynamic>>> sessionsByBundle;

  StudyState({
    this.isGenerating = false,
    this.generatingProgress,
    this.error,
    this.bundles = const [],
    this.sessionsByBundle = const {},
  });

  StudyState copyWith({
    bool? isGenerating,
    Object? generatingProgress = _sentinel,
    String? error,
    List<Map<String, dynamic>>? bundles,
    Map<String, List<Map<String, dynamic>>>? sessionsByBundle,
  }) {
    return StudyState(
      isGenerating: isGenerating ?? this.isGenerating,
      generatingProgress: identical(generatingProgress, _sentinel)
          ? this.generatingProgress
          : generatingProgress as String?,
      error: error, // Can be null to clear
      bundles: bundles ?? this.bundles,
      sessionsByBundle: sessionsByBundle ?? this.sessionsByBundle,
    );
  }
}

class StudyNotifier extends StateNotifier<StudyState> {
  final AiStudyService _aiService;
  final _uuid = const Uuid();

  StudyNotifier(this._aiService) : super(StudyState());

  Future<void> loadBundles(String materialId) async {
    try {
      final bundles = await DatabaseHelper.instance
          .getQuestionBundlesForMaterial(materialId);
      state = state.copyWith(bundles: bundles);
      // Load sessions for all these bundles
      final newSessionsMap = <String, List<Map<String, dynamic>>>{};
      for (final bundle in bundles) {
        final bundleId = bundle['id'] as String;
        newSessionsMap[bundleId] = await DatabaseHelper.instance
            .getStudySessionsForBundle(bundleId);
      }
      state = state.copyWith(sessionsByBundle: newSessionsMap);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteBundle(String materialId, String bundleId) async {
    try {
      await DatabaseHelper.instance.deleteQuestionBundle(bundleId);
      await loadBundles(materialId);
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete bundle: $e');
    }
  }

  Future<void> generateQuestions({
    required String materialId,
    required int pageFrom,
    required int pageTo,
    required int count,
  }) async {
    state = state.copyWith(isGenerating: true, error: null);
    try {
      // 1. Fetch chunks in page range
      final chunks = await DatabaseHelper.instance.getChunksForMaterial(
        materialId,
      );
      final relevantChunks = chunks.where((chunk) {
        final pageNum = chunk[DatabaseHelper.columnPageNumber] as int? ?? 1;
        return pageNum >= pageFrom && pageNum <= pageTo;
      }).toList();

      if (relevantChunks.isEmpty) {
        throw Exception('No content found in the specified page range.');
      }

      await _aiService.initialize();
      List<dynamic> allGeneratedQuestions = [];

      // Safe limit for 4096 tokens is around 12,000 characters
      const int maxCharsPerBatch = 7500;
      String currentBatch = "";

      // 2. Group text into safe-sized batches
      List<String> textBatches = [];
      List<int> batchEndPages = [];
      int currentBatchEndPage = pageFrom;

      for (var chunk in relevantChunks) {
        String content = chunk[DatabaseHelper.columnContent] as String;
        int pageNum =
            chunk[DatabaseHelper.columnPageNumber] as int? ?? pageFrom;
        final sourceType =
            chunk[DatabaseHelper.columnSourceType] as String? ??
            'training data';
        final chunkIndex = chunk[DatabaseHelper.columnChunkIndex] as int? ?? 0;
        final labeledContent =
            '[Source: page $pageNum, chunk ${chunkIndex + 1}, $sourceType]\n$content';

        // Split massive content into smaller pieces if it's too big by itself
        List<String> subContents = [];
        if (labeledContent.length > maxCharsPerBatch) {
          int start = 0;
          while (start < labeledContent.length) {
            int end = start + maxCharsPerBatch;
            if (end > labeledContent.length) end = labeledContent.length;
            subContents.add(labeledContent.substring(start, end));
            start = end;
          }
        } else {
          subContents.add(labeledContent);
        }

        for (var subContent in subContents) {
          if ((currentBatch.length + subContent.length) > maxCharsPerBatch &&
              currentBatch.isNotEmpty) {
            textBatches.add(currentBatch);
            batchEndPages.add(currentBatchEndPage);
            currentBatch = subContent; // Start new batch
            currentBatchEndPage = pageNum;
          } else {
            // Add spacing between chunks
            currentBatch += currentBatch.isEmpty
                ? subContent
                : "\n\n$subContent";
            currentBatchEndPage = pageNum;
          }
        }
      }
      if (currentBatch.isNotEmpty) {
        textBatches.add(currentBatch);
        batchEndPages.add(currentBatchEndPage);
      }

      // 3. Distribute the requested question count across the batches evenly
      int baseCountPerBatch = count ~/ textBatches.length;
      int remainder = count % textBatches.length;

      // 4. Save initial empty bundle to database
      final bundleId = _uuid.v4();
      final params = jsonEncode({
        'pageFrom': pageFrom,
        'pageTo': pageTo,
        'count': count,
        'chunkCount': relevantChunks.length,
      });

      await DatabaseHelper.instance.insertQuestionBundle({
        DatabaseHelper.columnBundleId: bundleId,
        DatabaseHelper.columnBundleMaterialId: materialId,
        DatabaseHelper.columnBundleCreatedAt:
            DateTime.now().millisecondsSinceEpoch,
        DatabaseHelper.columnBundleParams: params,
        DatabaseHelper.columnBundleQuestions: jsonEncode([]),
      });
      await loadBundles(materialId);

      // 5. Generate questions for each batch and update bundle
      for (int i = 0; i < textBatches.length; i++) {
        // Update UI progress
        state = state.copyWith(
          generatingProgress: 'Processing up to page ${batchEndPages[i]}...',
        );

        // Distribute remainder to the first few batches
        int questionsToRequest = baseCountPerBatch + (i < remainder ? 1 : 0);

        if (questionsToRequest > 0) {
          String textContext = textBatches[i];

          bool batchSuccess = false;
          for (int attempt = 0; attempt < 2 && !batchSuccess; attempt++) {
            try {
              if (attempt > 0) {
                state = state.copyWith(
                  generatingProgress: 'Retrying page ${batchEndPages[i]}...',
                );
              }
              final batchQuestions = await _aiService.generateQuestions(
                textContext,
                questionsToRequest,
              );
              allGeneratedQuestions.addAll(batchQuestions);
              batchSuccess = true;
            } catch (e) {
              debugPrint(
                'Batch $i on page ${batchEndPages[i]} attempt $attempt failed: $e',
              );
              if (attempt == 1) {
                // Both attempts failed, skip this batch
                debugPrint('Skipping batch $i after 2 failed attempts.');
              }
            }
          }

          // Update bundle in database incrementally
          await DatabaseHelper.instance.updateQuestionBundle(bundleId, {
            DatabaseHelper.columnBundleQuestions: jsonEncode(
              allGeneratedQuestions,
            ),
          });
          // Reload bundles so UI updates with new questions immediately
          await loadBundles(materialId);
        }
      }

      // 6. Dispose engine to free GPU for other features
      await _aiService.dispose();

      // 7. Final reload
      await loadBundles(materialId);

      if (allGeneratedQuestions.isEmpty) {
        await DatabaseHelper.instance.deleteQuestionBundle(bundleId);
        await loadBundles(materialId);
        throw Exception('Failed to generate any questions. Please try again.');
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to generate questions: $e');
    } finally {
      state = state.copyWith(isGenerating: false, generatingProgress: null);
    }
  }

  Future<Map<String, dynamic>> evaluateSession({
    required String bundleId,
    required List<String> questions,
    required List<String> userAnswers,
    required bool checkGrammar,
  }) async {
    try {
      await _aiService.initialize();
      final evaluation = await _aiService.evaluateAnswers(
        questions,
        userAnswers,
        checkGrammar,
      );

      final sessionId = _uuid.v4();
      await DatabaseHelper.instance.insertStudySession({
        DatabaseHelper.columnSessionId: sessionId,
        DatabaseHelper.columnSessionBundleId: bundleId,
        DatabaseHelper.columnSessionCreatedAt:
            DateTime.now().millisecondsSinceEpoch,
        DatabaseHelper.columnSessionAnswers: jsonEncode(userAnswers),
        DatabaseHelper.columnSessionEvaluation: jsonEncode(evaluation),
      });

      return evaluation;
    } catch (e) {
      throw Exception('Failed to evaluate answers: $e');
    }
  }
}
