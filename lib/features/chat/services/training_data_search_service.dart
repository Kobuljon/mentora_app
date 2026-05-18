import 'dart:math' as math;

import '../../../core/database/database_helper.dart';

class TrainingDataMatch {
  const TrainingDataMatch({
    required this.filename,
    required this.content,
    required this.sourceType,
    required this.chunkIndex,
    required this.pageNumber,
    required this.score,
  });

  final String filename;
  final String content;
  final String sourceType;
  final int chunkIndex;
  final int pageNumber;
  final double score;

  String get sourceLabel {
    final page = pageNumber > 0 ? 'page $pageNumber' : 'chunk $chunkIndex';
    return '$filename, $page';
  }
}

class TrainingDataSearchService {
  TrainingDataSearchService({DatabaseHelper? database})
    : _database = database ?? DatabaseHelper.instance;

  static final _wordPattern = RegExp(r"[a-zA-Z0-9']+");
  static const _minimumScore = 1.3;
  static const _maxSnippetChars = 900;
  static const _stopWords = {
    'about',
    'after',
    'again',
    'also',
    'answer',
    'because',
    'before',
    'could',
    'does',
    'from',
    'give',
    'have',
    'help',
    'into',
    'make',
    'more',
    'most',
    'notes',
    'please',
    'question',
    'questions',
    'should',
    'show',
    'tell',
    'than',
    'that',
    'their',
    'them',
    'then',
    'there',
    'these',
    'they',
    'this',
    'topic',
    'uploaded',
    'using',
    'what',
    'when',
    'where',
    'which',
    'with',
    'would',
  };

  final DatabaseHelper _database;

  Future<List<TrainingDataMatch>> search(String query, {int limit = 5}) async {
    final queryTokens = _tokenize(query);
    final rows = await _database.getSearchableTrainingChunks();
    if (rows.isEmpty) return const [];
    if (queryTokens.isEmpty) {
      return _wantsUploadedMaterialContext(query)
          ? _recentMatches(rows, limit: limit)
          : const [];
    }

    final matches = <TrainingDataMatch>[];

    for (final row in rows) {
      final content = (row[DatabaseHelper.columnContent] as String? ?? '')
          .trim();
      if (content.isEmpty) continue;

      final score = _score(queryTokens, content);
      if (score < _minimumScore) continue;

      matches.add(
        TrainingDataMatch(
          filename:
              row[DatabaseHelper.columnFilename] as String? ?? 'Uploaded note',
          content: _relevantWindow(content, queryTokens),
          sourceType: row[DatabaseHelper.columnSourceType] as String? ?? 'text',
          chunkIndex: row[DatabaseHelper.columnChunkIndex] as int? ?? 0,
          pageNumber: row[DatabaseHelper.columnPageNumber] as int? ?? 1,
          score: score,
        ),
      );
    }

    matches.sort((a, b) => b.score.compareTo(a.score));
    final ranked = matches.take(limit).toList(growable: false);
    if (ranked.isNotEmpty) return ranked;

    return _wantsUploadedMaterialContext(query)
        ? _recentMatches(rows, limit: limit)
        : const [];
  }

  List<TrainingDataMatch> _recentMatches(
    List<Map<String, dynamic>> rows, {
    required int limit,
  }) {
    final matches = <TrainingDataMatch>[];
    for (final row in rows) {
      final content = (row[DatabaseHelper.columnContent] as String? ?? '')
          .trim();
      if (content.isEmpty) continue;
      matches.add(
        TrainingDataMatch(
          filename:
              row[DatabaseHelper.columnFilename] as String? ?? 'Uploaded note',
          content: _firstWindow(content),
          sourceType: row[DatabaseHelper.columnSourceType] as String? ?? 'text',
          chunkIndex: row[DatabaseHelper.columnChunkIndex] as int? ?? 0,
          pageNumber: row[DatabaseHelper.columnPageNumber] as int? ?? 1,
          score: 0.1,
        ),
      );
      if (matches.length == limit) break;
    }
    return matches;
  }

  double _score(Set<String> queryTokens, String content) {
    final contentTokens = _tokenize(content);
    if (contentTokens.isEmpty) return 0;

    final frequencies = <String, int>{};
    for (final token in contentTokens) {
      frequencies[token] = (frequencies[token] ?? 0) + 1;
    }

    var matchedTerms = 0;
    var score = 0.0;
    for (final token in queryTokens) {
      final frequency = frequencies[token] ?? 0;
      if (frequency > 0) {
        matchedTerms++;
        score += 1.5 + math.log(1 + frequency);
        continue;
      }

      final hasSoftMatch = contentTokens.any(
        (contentToken) =>
            contentToken.length > 4 &&
            token.length > 4 &&
            (contentToken.startsWith(token) || token.startsWith(contentToken)),
      );
      if (hasSoftMatch) {
        matchedTerms++;
        score += 0.65;
      }
    }

    if (matchedTerms == 0) return 0;

    final coverage = matchedTerms / queryTokens.length;
    if (coverage < 0.22 && matchedTerms < 2) return 0;

    return score * (0.75 + coverage);
  }

  Set<String> _tokenize(String value) {
    return _wordPattern
        .allMatches(value.toLowerCase())
        .map((match) => match.group(0)!)
        .where((token) => token.length > 2 && !_stopWords.contains(token))
        .toSet();
  }

  bool _wantsUploadedMaterialContext(String query) {
    final q = query.toLowerCase();
    return RegExp(
      r'\b(uploaded|upload|material|materials|notes|lessons|files|documents|pdf|audio|transcript|quiz me|flashcards|review)\b',
    ).hasMatch(q);
  }

  String _firstWindow(String content) {
    final compact = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= _maxSnippetChars) return compact;
    return '${compact.substring(0, _maxSnippetChars).trim()} ...';
  }

  String _relevantWindow(String content, Set<String> queryTokens) {
    final compact = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= _maxSnippetChars) return compact;

    var bestIndex = 0;
    for (final token in queryTokens) {
      final index = compact.toLowerCase().indexOf(token);
      if (index >= 0) {
        bestIndex = index;
        break;
      }
    }

    final halfWindow = (_maxSnippetChars / 2).floor();
    final start = math.max(0, bestIndex - halfWindow);
    final end = math.min(compact.length, start + _maxSnippetChars);
    final window = compact.substring(start, end).trim();
    final prefix = start > 0 ? '... ' : '';
    final suffix = end < compact.length ? ' ...' : '';
    return '$prefix$window$suffix';
  }
}
