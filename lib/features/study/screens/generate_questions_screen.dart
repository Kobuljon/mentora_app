import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_helper.dart';
import '../providers/study_provider.dart';

class GenerateQuestionsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> material;

  const GenerateQuestionsScreen({super.key, required this.material});

  @override
  ConsumerState<GenerateQuestionsScreen> createState() =>
      _GenerateQuestionsScreenState();
}

class _GenerateQuestionsScreenState
    extends ConsumerState<GenerateQuestionsScreen> {
  final _pageFromCtrl = TextEditingController();
  final _pageToCtrl = TextEditingController();
  final _countCtrl = TextEditingController(text: '5');
  final _formKey = GlobalKey<FormState>();

  List<_PageSummary> _pages = const [];
  bool _isLoading = true;
  int _chunkCount = 0;
  int _characterCount = 0;

  int get _minPage => _pages.isEmpty ? 1 : _pages.first.pageNumber;
  int get _maxPage => _pages.isEmpty ? 1 : _pages.last.pageNumber;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadTrainingData);
  }

  @override
  void dispose() {
    _pageFromCtrl.dispose();
    _pageToCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTrainingData() async {
    final materialId = widget.material[DatabaseHelper.columnId] as String;
    final chunks = await DatabaseHelper.instance.getChunksForMaterial(
      materialId,
    );
    final pages = _buildPageSummaries(chunks);

    if (!mounted) return;
    setState(() {
      _pages = pages;
      _chunkCount = chunks.length;
      _characterCount = chunks.fold<int>(0, (total, chunk) {
        final content = chunk[DatabaseHelper.columnContent] as String? ?? '';
        return total + content.length;
      });
      _isLoading = false;
      if (pages.isNotEmpty) {
        _pageFromCtrl.text = pages.first.pageNumber.toString();
        _pageToCtrl.text = pages.last.pageNumber.toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final studyState = ref.watch(studyProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filename =
        widget.material[DatabaseHelper.columnFilename] as String? ??
        'Training material';
    final type =
        widget.material[DatabaseHelper.columnType] as String? ?? 'file';
    final isGenerating = studyState.isGenerating;

    return Scaffold(
      appBar: AppBar(title: const Text('Generate Questions')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pages.isEmpty
          ? _EmptyTrainingData(filename: filename)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MaterialSummaryCard(
                      filename: filename,
                      type: type,
                      pageCount: _pages.length,
                      chunkCount: _chunkCount,
                      characterCount: _characterCount,
                      minPage: _minPage,
                      maxPage: _maxPage,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Question range',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(
                            Icons.select_all_rounded,
                            size: 18,
                          ),
                          label: const Text('All pages'),
                          onPressed: isGenerating
                              ? null
                              : () => _setRange(_minPage, _maxPage),
                        ),
                        ActionChip(
                          avatar: const Icon(
                            Icons.first_page_rounded,
                            size: 18,
                          ),
                          label: const Text('First 5'),
                          onPressed: isGenerating
                              ? null
                              : () => _setRange(
                                  _minPage,
                                  (_minPage + 4).clamp(_minPage, _maxPage),
                                ),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.last_page_rounded, size: 18),
                          label: const Text('Last 5'),
                          onPressed: isGenerating
                              ? null
                              : () => _setRange(
                                  (_maxPage - 4).clamp(_minPage, _maxPage),
                                  _maxPage,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _NumberField(
                            controller: _pageFromCtrl,
                            label: 'From page',
                            helperText: 'Min $_minPage',
                            enabled: !isGenerating,
                            validator: _validateFromPage,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _NumberField(
                            controller: _pageToCtrl,
                            label: 'To page',
                            helperText: 'Max $_maxPage',
                            enabled: !isGenerating,
                            validator: _validateToPage,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _NumberField(
                      controller: _countCtrl,
                      label: 'Number of questions',
                      helperText: '1-30 recommended',
                      enabled: !isGenerating,
                      validator: _validateQuestionCount,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Available pages',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _pages.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            color: colorScheme.outlineVariant,
                          ),
                          itemBuilder: (context, index) {
                            final page = _pages[index];
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 17,
                                child: Text(page.pageNumber.toString()),
                              ),
                              title: Text(
                                page.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${page.chunkCount} chunks • ${page.characterCount} chars',
                              ),
                              onTap: isGenerating
                                  ? null
                                  : () => _setRange(
                                      page.pageNumber,
                                      page.pageNumber,
                                    ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (studyState.error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        studyState.error!,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ],
                    if (isGenerating) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(color: colorScheme.primary),
                      const SizedBox(height: 8),
                      Text(
                        studyState.generatingProgress ??
                            'Generating questions...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: isGenerating ? null : _generateQuestions,
                      icon: isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_rounded),
                      label: Text(isGenerating ? 'Generating...' : 'Generate'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  List<_PageSummary> _buildPageSummaries(List<Map<String, dynamic>> chunks) {
    final byPage = <int, List<Map<String, dynamic>>>{};
    for (final chunk in chunks) {
      final pageNumber = chunk[DatabaseHelper.columnPageNumber] as int? ?? 1;
      byPage.putIfAbsent(pageNumber, () => []).add(chunk);
    }

    final pages = byPage.entries.map((entry) {
      final content = entry.value
          .map((chunk) => chunk[DatabaseHelper.columnContent] as String? ?? '')
          .where((text) => text.trim().isNotEmpty)
          .join('\n');
      return _PageSummary(
        pageNumber: entry.key,
        title: _deriveTitle(content, entry.key),
        chunkCount: entry.value.length,
        characterCount: content.length,
      );
    }).toList();

    pages.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
    return pages;
  }

  String _deriveTitle(String content, int pageNumber) {
    final lines = content
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.length >= 4)
        .where((line) => RegExp(r'[A-Za-z]').hasMatch(line))
        .toList();
    if (lines.isEmpty) return 'Page $pageNumber';

    final heading = lines.firstWhere(
      (line) => line.length <= 80,
      orElse: () => lines.first,
    );
    return heading.length <= 80 ? heading : '${heading.substring(0, 77)}...';
  }

  void _setRange(int from, int to) {
    setState(() {
      _pageFromCtrl.text = from.toString();
      _pageToCtrl.text = to.toString();
    });
  }

  String? _validateFromPage(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null) return 'Required';
    if (number < _minPage || number > _maxPage) {
      return 'Use $_minPage-$_maxPage';
    }
    final to = int.tryParse(_pageToCtrl.text.trim());
    if (to != null && number > to) return 'After To';
    return null;
  }

  String? _validateToPage(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null) return 'Required';
    if (number < _minPage || number > _maxPage) {
      return 'Use $_minPage-$_maxPage';
    }
    final from = int.tryParse(_pageFromCtrl.text.trim());
    if (from != null && number < from) return 'Before From';
    return null;
  }

  String? _validateQuestionCount(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null) return 'Required';
    if (number < 1) return 'Min 1';
    if (number > 30) return 'Max 30';
    return null;
  }

  Future<void> _generateQuestions() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(studyProvider.notifier);
    final materialId = widget.material[DatabaseHelper.columnId] as String;
    await notifier.generateQuestions(
      materialId: materialId,
      pageFrom: int.parse(_pageFromCtrl.text.trim()),
      pageTo: int.parse(_pageToCtrl.text.trim()),
      count: int.parse(_countCtrl.text.trim()),
    );

    if (!mounted) return;
    final state = ref.read(studyProvider);
    if (state.error == null) Navigator.pop(context);
  }
}

class _PageSummary {
  const _PageSummary({
    required this.pageNumber,
    required this.title,
    required this.chunkCount,
    required this.characterCount,
  });

  final int pageNumber;
  final String title;
  final int chunkCount;
  final int characterCount;
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.helperText,
    required this.enabled,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String helperText;
  final bool enabled;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: validator,
    );
  }
}

class _MaterialSummaryCard extends StatelessWidget {
  const _MaterialSummaryCard({
    required this.filename,
    required this.type,
    required this.pageCount,
    required this.chunkCount,
    required this.characterCount,
    required this.minPage,
    required this.maxPage,
  });

  final String filename;
  final String type;
  final int pageCount;
  final int chunkCount;
  final int characterCount;
  final int minPage;
  final int maxPage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            filename,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$type • pages $minPage-$maxPage',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'Pages',
                  value: pageCount.toString(),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'Chunks',
                  value: chunkCount.toString(),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'Chars',
                  value: _compactNumber(characterCount),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _compactNumber(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _EmptyTrainingData extends StatelessWidget {
  const _EmptyTrainingData({required this.filename});

  final String filename;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.find_in_page_outlined,
              size: 54,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'No readable training data',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$filename does not have saved text chunks yet.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
