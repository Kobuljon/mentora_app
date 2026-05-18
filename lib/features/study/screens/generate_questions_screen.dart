import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_logo.dart';
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
    Future.microtask(_loadContent);
  }

  @override
  void dispose() {
    _pageFromCtrl.dispose();
    _pageToCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final studyState = ref.watch(studyProvider);
    final filename =
        widget.material[DatabaseHelper.columnFilename] as String? ?? 'Material';
    final isGenerating = studyState.isGenerating;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: const Text('Generate Quiz')),
      body: _isLoading
          ? const Center(child: MentoraLogoLoader(size: 34))
          : _pages.isEmpty
          ? _EmptyContent(filename: filename)
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryHero(
                      filename: filename,
                      pageCount: _pages.length,
                      chunkCount: _chunkCount,
                      characterCount: _characterCount,
                      minPage: _minPage,
                      maxPage: _maxPage,
                    ),
                    const SizedBox(height: 20),
                    _SectionHeader(title: 'Pages'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _PageDropdownField(
                            value: int.tryParse(_pageFromCtrl.text.trim()),
                            items: _pages,
                            label: 'From page',
                            enabled: !isGenerating,
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _pageFromCtrl.text = value.toString();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PageDropdownField(
                            value: int.tryParse(_pageToCtrl.text.trim()),
                            items: _pages,
                            label: 'To page',
                            enabled: !isGenerating,
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _pageToCtrl.text = value.toString();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const _SectionHeader(title: 'Number of questions'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final n in [3, 5, 10, 15, 20])
                          _CountChip(
                            value: n,
                            selected: int.tryParse(_countCtrl.text) == n,
                            onTap: isGenerating
                                ? null
                                : () => setState(
                                    () => _countCtrl.text = n.toString(),
                                  ),
                          ),
                        _InlineCustomCountField(
                          controller: _countCtrl,
                          enabled: !isGenerating,
                          validator: _validateQuestionCount,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _SectionHeader(title: 'Available pages'),
                    const SizedBox(height: 10),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 280),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _pages.length,
                          separatorBuilder: (context, index) =>
                              Divider(height: 1, color: scheme.outlineVariant),
                          itemBuilder: (context, index) {
                            final page = _pages[index];
                            return ListTile(
                              dense: true,
                              leading: Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: scheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  page.pageNumber.toString(),
                                  style: TextStyle(
                                    color: scheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              title: Text(
                                page.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${page.chunkCount} chunks • ${page.characterCount} chars',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: scheme.onErrorContainer,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                studyState.error!,
                                style: TextStyle(
                                  color: scheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (isGenerating) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: MentoraLogoLoader(size: 18),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Generating...',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              color: scheme.primary,
                              backgroundColor: scheme.surfaceContainerHigh,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              studyState.generatingProgress ??
                                  'Working on it...',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: isGenerating ? null : _generateQuestions,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: Text(
                        isGenerating ? 'Generating...' : 'Generate quiz',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
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

  String? _validateQuestionCount(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null) return 'Required';
    if (number < 1) return 'Min 1';
    if (number > 30) return 'Max 30';
    return null;
  }

  Future<void> _generateQuestions() async {
    if (!_formKey.currentState!.validate()) return;

    final fromPage = int.tryParse(_pageFromCtrl.text.trim());
    final toPage = int.tryParse(_pageToCtrl.text.trim());
    if (fromPage == null || toPage == null || fromPage > toPage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a valid page range.')),
      );
      return;
    }

    final notifier = ref.read(studyProvider.notifier);
    final materialId = widget.material[DatabaseHelper.columnId] as String;
    await notifier.generateQuestions(
      materialId: materialId,
      pageFrom: fromPage,
      pageTo: toPage,
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.value,
    required this.selected,
    required this.onTap,
  });
  final int value;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected ? scheme.primary : scheme.surfaceContainer;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Text(
            value.toString(),
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineCustomCountField extends StatelessWidget {
  const _InlineCustomCountField({
    required this.controller,
    required this.enabled,
    required this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? Function(String?) validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 124,
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: validator,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: 'Custom',
          isDense: true,
          filled: true,
          fillColor: scheme.surfaceContainer,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.primary, width: 1.4),
          ),
        ),
      ),
    );
  }
}

class _PageDropdownField extends StatelessWidget {
  const _PageDropdownField({
    required this.value,
    required this.items,
    required this.label,
    required this.enabled,
    required this.onChanged,
  });

  final int? value;
  final List<_PageSummary> items;
  final String label;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final item in items)
          DropdownMenuItem<int>(
            value: item.pageNumber,
            child: Text(
              'P${item.pageNumber} • ${item.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      selectedItemBuilder: (context) {
        return [
          for (final item in items)
            Text(
              'Page ${item.pageNumber}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ];
      },
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _SummaryHero extends StatelessWidget {
  const _SummaryHero({
    required this.filename,
    required this.pageCount,
    required this.chunkCount,
    required this.characterCount,
    required this.minPage,
    required this.maxPage,
  });

  final String filename;
  final int pageCount;
  final int chunkCount;
  final int characterCount;
  final int minPage;
  final int maxPage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, Color(0xFF4C1D95)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: scheme.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      filename,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pages $minPage-$maxPage',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MetricChip(value: pageCount.toString(), label: 'Pages'),
              const SizedBox(width: 8),
              _MetricChip(value: chunkCount.toString(), label: 'Chunks'),
              const SizedBox(width: 8),
              _MetricChip(value: _compact(characterCount), label: 'Chars'),
            ],
          ),
        ],
      ),
    );
  }

  static String _compact(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: scheme.onPrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onPrimary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyContent extends StatelessWidget {
  const _EmptyContent({required this.filename});
  final String filename;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.find_in_page_outlined,
                size: 42,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No readable content',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$filename does not have parsed text yet.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
