import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../study/providers/study_provider.dart';

/// Browse and manage the parsed content (excerpts) extracted from a material.
class MaterialContentScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> material;

  const MaterialContentScreen({super.key, required this.material});

  @override
  ConsumerState<MaterialContentScreen> createState() =>
      _MaterialContentScreenState();
}

class _MaterialContentScreenState extends ConsumerState<MaterialContentScreen> {
  List<Map<String, dynamic>> _chunks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChunks();
  }

  Future<void> _loadChunks() async {
    setState(() => _isLoading = true);
    final materialId = widget.material[DatabaseHelper.columnId];
    final chunks = await DatabaseHelper.instance.getChunksForMaterial(
      materialId,
    );
    if (!mounted) return;
    setState(() {
      _chunks = chunks;
      _isLoading = false;
    });
  }

  Future<void> _deleteChunk(String chunkId) async {
    await DatabaseHelper.instance.deleteChunk(chunkId);
    if (!mounted) return;
    await _loadChunks();
  }

  Future<void> _deleteMaterial() async {
    final materialId = widget.material[DatabaseHelper.columnId];
    ref
        .read(studyProvider.notifier)
        .cancelGenerationForMaterial(materialId.toString());
    await DatabaseHelper.instance.deleteMaterial(materialId);
    if (mounted) Navigator.pop(context, true);
  }

  String get _filename =>
      widget.material[DatabaseHelper.columnFilename] as String? ?? 'Material';

  int get _totalChars => _chunks.fold<int>(0, (sum, c) {
    final content = c[DatabaseHelper.columnContent] as String? ?? '';
    return sum + content.length;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Material Content'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadChunks,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Delete material',
            onPressed: _showDeleteMaterialConfirmation,
            icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadChunks,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _ContentHero(
                    filename: _filename,
                    excerptCount: _chunks.length,
                    totalChars: _totalChars,
                  ),
                  const SizedBox(height: 20),
                  if (_chunks.isEmpty)
                    _EmptyContent()
                  else ...[
                    Text(
                      'Excerpts',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final chunk in _chunks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ExcerptCard(
                          chunk: chunk,
                          onTap: () => _showExcerpt(chunk),
                          onDelete: () => _showDeleteChunkConfirmation(
                            chunk[DatabaseHelper.columnChunkId] as String,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  void _showExcerpt(Map<String, dynamic> chunk) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final index = chunk[DatabaseHelper.columnChunkIndex];
    final content = chunk[DatabaseHelper.columnContent] as String? ?? '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Excerpt $index',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${content.length} characters',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: Text(
                    content,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteChunkConfirmation(String chunkId) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete excerpt?'),
        content: const Text(
          'This will remove this excerpt from your material content.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.errorContainer,
              foregroundColor: Theme.of(ctx).colorScheme.onErrorContainer,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await Future<void>.delayed(Duration.zero);
              if (!mounted) return;
              await _deleteChunk(chunkId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteMaterialConfirmation() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete material?'),
        content: const Text(
          'This will permanently delete the material and all of its excerpts. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await Future<void>.delayed(Duration.zero);
              if (!mounted) return;
              await _deleteMaterial();
            },
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
  }
}

class _ContentHero extends StatelessWidget {
  const _ContentHero({
    required this.filename,
    required this.excerptCount,
    required this.totalChars,
  });

  final String filename;
  final int excerptCount;
  final int totalChars;

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
                child: Icon(Icons.menu_book_rounded, color: scheme.onPrimary),
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
                      'Parsed content',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroStat(value: excerptCount.toString(), label: 'Excerpts'),
              const SizedBox(width: 12),
              _HeroStat(value: _compact(totalChars), label: 'Characters'),
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

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: scheme.onPrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
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
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.find_in_page_outlined, size: 48, color: scheme.primary),
          const SizedBox(height: 12),
          Text(
            'No excerpts yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This material has no parsed text content.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExcerptCard extends StatelessWidget {
  const _ExcerptCard({
    required this.chunk,
    required this.onTap,
    required this.onDelete,
  });

  final Map<String, dynamic> chunk;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final content = chunk[DatabaseHelper.columnContent] as String? ?? '';
    final index = chunk[DatabaseHelper.columnChunkIndex];
    final sourceType =
        chunk[DatabaseHelper.columnSourceType] as String? ?? 'text';

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  index.toString(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content.trim().isEmpty ? '(empty)' : content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _TinyChip(
                          label: sourceType.toUpperCase(),
                          color: scheme.secondary,
                        ),
                        const SizedBox(width: 6),
                        _TinyChip(
                          label: '${content.length} chars',
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  const _TinyChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
