import 'dart:convert';
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
  final String? generatingMaterialId;
  final String? generatingProgress;
  final String? error;
  final List<Map<String, dynamic>> bundles;
  final Map<String, List<Map<String, dynamic>>> sessionsByBundle;

  StudyState({
    this.isGenerating = false,
    this.generatingMaterialId,
    this.generatingProgress,
    this.error,
    this.bundles = const [],
    this.sessionsByBundle = const {},
  });

  StudyState copyWith({
    bool? isGenerating,
    Object? generatingMaterialId = _sentinel,
    Object? generatingProgress = _sentinel,
    String? error,
    List<Map<String, dynamic>>? bundles,
    Map<String, List<Map<String, dynamic>>>? sessionsByBundle,
  }) {
    return StudyState(
      isGenerating: isGenerating ?? this.isGenerating,
      generatingMaterialId: identical(generatingMaterialId, _sentinel)
          ? this.generatingMaterialId
          : generatingMaterialId as String?,
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
  int _generationRunId = 0;
  String? _activeGenerationMaterialId;

  StudyNotifier(this._aiService) : super(StudyState());

  Future<void> loadBundles(String materialId) async {
    try {
      final bundles = await DatabaseHelper.instance
          .getQuestionBundlesForMaterial(materialId);
      if (!mounted) return;
      state = state.copyWith(bundles: bundles);
      // Load sessions for all these bundles
      final newSessionsMap = <String, List<Map<String, dynamic>>>{};
      for (final bundle in bundles) {
        final bundleId = bundle['id'] as String;
        newSessionsMap[bundleId] = await DatabaseHelper.instance
            .getStudySessionsForBundle(bundleId);
      }
      if (!mounted) return;
      state = state.copyWith(sessionsByBundle: newSessionsMap);
    } catch (e) {
      if (!mounted) return;
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

  void cancelGenerationForMaterial(String materialId) {
    if (_activeGenerationMaterialId != materialId) return;
    _generationRunId++;
    _activeGenerationMaterialId = null;
    state = state.copyWith(
      isGenerating: false,
      generatingMaterialId: null,
      generatingProgress: null,
      bundles: const [],
      sessionsByBundle: const {},
    );
  }

  Future<void> generateQuestions({
    required String materialId,
    required int pageFrom,
    required int pageTo,
    required int count,
  }) async {
    if (state.isGenerating) {
      state = state.copyWith(
        error: 'Finish the current quiz generation before starting another.',
      );
      return;
    }
    final runId = ++_generationRunId;
    _activeGenerationMaterialId = materialId;
    state = state.copyWith(
      isGenerating: true,
      generatingMaterialId: materialId,
      error: null,
    );
    try {
      // 1. Fetch chunks in page range
      final chunks = await DatabaseHelper.instance.getChunksForMaterial(
        materialId,
      );
      if (!_isActiveGeneration(runId, materialId)) return;
      final relevantChunks = chunks.where((chunk) {
        final pageNum = chunk[DatabaseHelper.columnPageNumber] as int? ?? 1;
        return pageNum >= pageFrom && pageNum <= pageTo;
      }).toList();

      if (relevantChunks.isEmpty) {
        throw Exception('No content found in the specified page range.');
      }

      await _aiService.initialize();
      if (!_isActiveGeneration(runId, materialId)) return;
      List<String> allGeneratedQuestions = [];

      // Keep local prompts small enough for mobile LiteRT memory pressure.
      const int maxCharsPerBatch = 1800;
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

      // 3. Save initial empty bundle to database
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
      if (!_isActiveGeneration(runId, materialId)) return;
      await loadBundles(materialId);

      // 4. Use a single compact generation call on local devices. Loading and
      // decoding the model is the expensive part; repeated calls are painful.
      if (!_isActiveGeneration(runId, materialId)) return;
      state = state.copyWith(
        generatingProgress: 'Generating $count questions...',
      );
      final compactContext = _buildCompactQuizContext(textBatches);
      allGeneratedQuestions = _appendUniqueQuestions(
        allGeneratedQuestions,
        await _aiService.generateQuestions(compactContext, count),
        count,
      );
      if (!_isActiveGeneration(runId, materialId)) return;
      await DatabaseHelper.instance.updateQuestionBundle(bundleId, {
        DatabaseHelper.columnBundleQuestions: jsonEncode(allGeneratedQuestions),
      });
      await loadBundles(materialId);

      // 5. Dispose engine to free GPU for other features
      await _aiService.dispose();

      // 6. Final reload
      if (!_isActiveGeneration(runId, materialId)) return;
      await loadBundles(materialId);

      if (allGeneratedQuestions.isEmpty) {
        await DatabaseHelper.instance.deleteQuestionBundle(bundleId);
        await loadBundles(materialId);
        throw Exception('Failed to generate any questions. Please try again.');
      }
    } catch (e) {
      if (_isActiveGeneration(runId, materialId)) {
        state = state.copyWith(error: 'Failed to generate questions: $e');
      }
    } finally {
      await _aiService.dispose();
      if (_isActiveGeneration(runId, materialId)) {
        _activeGenerationMaterialId = null;
        state = state.copyWith(
          isGenerating: false,
          generatingMaterialId: null,
          generatingProgress: null,
        );
      }
    }
  }

  bool _isActiveGeneration(int runId, String materialId) {
    return mounted &&
        _generationRunId == runId &&
        _activeGenerationMaterialId == materialId;
  }

  List<String> _appendUniqueQuestions(
    List<String> existing,
    List<String> incoming,
    int limit,
  ) {
    final merged = [...existing];
    final seen = existing.map(_questionFingerprint).toSet();
    for (final question in incoming) {
      final normalized = question.trim();
      if (normalized.isEmpty) continue;
      if (!seen.add(_questionFingerprint(normalized))) continue;
      merged.add(normalized);
      if (merged.length == limit) break;
    }
    return merged;
  }

  String _questionFingerprint(String question) {
    return question.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  String _buildCompactQuizContext(List<String> textBatches) {
    final combined = textBatches.join('\n\n');
    const maxChars = 2200;
    if (combined.length <= maxChars) return combined;

    final headLength = maxChars ~/ 2;
    final tailLength = maxChars - headLength;
    return '${combined.substring(0, headLength)}\n\n${combined.substring(combined.length - tailLength)}';
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
