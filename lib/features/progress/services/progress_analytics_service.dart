import 'dart:convert';

import '../../../core/database/database_helper.dart';

class ProgressAnalytics {
  const ProgressAnalytics({
    required this.materialCount,
    required this.questionBundleCount,
    required this.studySessionCount,
    required this.generatedQuestionCount,
    required this.answeredQuestionCount,
    required this.correctAnswerCount,
    required this.grammarFeedbackCount,
    required this.currentStreakDays,
    required this.lastSevenDays,
    required this.recentSessions,
    required this.materialBreakdown,
  });

  final int materialCount;
  final int questionBundleCount;
  final int studySessionCount;
  final int generatedQuestionCount;
  final int answeredQuestionCount;
  final int correctAnswerCount;
  final int grammarFeedbackCount;
  final int currentStreakDays;
  final List<DailyProgress> lastSevenDays;
  final List<RecentStudySession> recentSessions;
  final List<MaterialProgress> materialBreakdown;

  double get accuracy => answeredQuestionCount == 0
      ? 0
      : correctAnswerCount / answeredQuestionCount;

  double get grammarFeedbackRate => answeredQuestionCount == 0
      ? 0
      : grammarFeedbackCount / answeredQuestionCount;
}

class DailyProgress {
  const DailyProgress({required this.day, required this.sessions});

  final DateTime day;
  final int sessions;
}

class RecentStudySession {
  const RecentStudySession({
    required this.materialTitle,
    required this.createdAt,
    required this.questionCount,
    required this.correctCount,
  });

  final String materialTitle;
  final DateTime createdAt;
  final int questionCount;
  final int correctCount;

  double get accuracy => questionCount == 0 ? 0 : correctCount / questionCount;
}

class MaterialProgress {
  const MaterialProgress({
    required this.title,
    required this.type,
    required this.questionCount,
    required this.sessionCount,
    required this.correctCount,
    required this.answeredCount,
  });

  final String title;
  final String type;
  final int questionCount;
  final int sessionCount;
  final int correctCount;
  final int answeredCount;

  double get accuracy => answeredCount == 0 ? 0 : correctCount / answeredCount;
}

class ProgressAnalyticsService {
  const ProgressAnalyticsService._();

  static Future<ProgressAnalytics> load() async {
    final materials = await DatabaseHelper.instance.getAllMaterials();
    final materialProgress = <MaterialProgress>[];
    final recentSessions = <RecentStudySession>[];
    final sessionDays = <DateTime, int>{};

    var bundleCount = 0;
    var sessionCount = 0;
    var generatedQuestionCount = 0;
    var answeredQuestionCount = 0;
    var correctAnswerCount = 0;
    var grammarFeedbackCount = 0;

    for (final material in materials) {
      final materialId = material[DatabaseHelper.columnId] as String;
      final title =
          material[DatabaseHelper.columnFilename] as String? ?? 'Untitled';
      final type = material[DatabaseHelper.columnType] as String? ?? 'file';
      final bundles = await DatabaseHelper.instance
          .getQuestionBundlesForMaterial(materialId);

      bundleCount += bundles.length;
      var materialQuestions = 0;
      var materialSessions = 0;
      var materialCorrect = 0;
      var materialAnswered = 0;

      for (final bundle in bundles) {
        final questions = _decodeStringList(
          bundle[DatabaseHelper.columnBundleQuestions],
        );
        materialQuestions += questions.length;
        generatedQuestionCount += questions.length;

        final sessions = await DatabaseHelper.instance
            .getStudySessionsForBundle(
              bundle[DatabaseHelper.columnBundleId] as String,
            );
        sessionCount += sessions.length;
        materialSessions += sessions.length;

        for (final session in sessions) {
          final evaluation = _decodeMap(
            session[DatabaseHelper.columnSessionEvaluation],
          );
          final evals = evaluation['evaluations'];
          final evaluatedQuestions = evals is List ? evals : const [];
          final correct = evaluatedQuestions
              .whereType<Map>()
              .where((item) => item['isCorrect'] == true)
              .length;
          final grammarFeedback = evaluatedQuestions.whereType<Map>().where((
            item,
          ) {
            final value = item['grammarFeedback'];
            return value != null && value.toString().trim().isNotEmpty;
          }).length;
          final answered = evaluatedQuestions.length;

          answeredQuestionCount += answered;
          correctAnswerCount += correct;
          grammarFeedbackCount += grammarFeedback;
          materialAnswered += answered;
          materialCorrect += correct;

          final createdAt = DateTime.fromMillisecondsSinceEpoch(
            session[DatabaseHelper.columnSessionCreatedAt] as int,
          );
          final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
          sessionDays[day] = (sessionDays[day] ?? 0) + 1;
          recentSessions.add(
            RecentStudySession(
              materialTitle: title,
              createdAt: createdAt,
              questionCount: answered,
              correctCount: correct,
            ),
          );
        }
      }

      materialProgress.add(
        MaterialProgress(
          title: title,
          type: type,
          questionCount: materialQuestions,
          sessionCount: materialSessions,
          correctCount: materialCorrect,
          answeredCount: materialAnswered,
        ),
      );
    }

    recentSessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    materialProgress.sort((a, b) => b.sessionCount.compareTo(a.sessionCount));

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final lastSevenDays = [
      for (var offset = 6; offset >= 0; offset--)
        DailyProgress(
          day: todayDate.subtract(Duration(days: offset)),
          sessions:
              sessionDays[todayDate.subtract(Duration(days: offset))] ?? 0,
        ),
    ];

    return ProgressAnalytics(
      materialCount: materials.length,
      questionBundleCount: bundleCount,
      studySessionCount: sessionCount,
      generatedQuestionCount: generatedQuestionCount,
      answeredQuestionCount: answeredQuestionCount,
      correctAnswerCount: correctAnswerCount,
      grammarFeedbackCount: grammarFeedbackCount,
      currentStreakDays: _calculateStreak(sessionDays.keys.toSet()),
      lastSevenDays: lastSevenDays,
      recentSessions: recentSessions.take(5).toList(),
      materialBreakdown: materialProgress.take(5).toList(),
    );
  }

  static List<String> _decodeStringList(Object? raw) {
    if (raw is! String || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.map((item) => item.toString()).toList();
  }

  static Map<String, dynamic> _decodeMap(Object? raw) {
    if (raw is! String || raw.isEmpty) return const {};
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : const {};
  }

  static int _calculateStreak(Set<DateTime> activeDays) {
    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    var streak = 0;

    while (activeDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}
