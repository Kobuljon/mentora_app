import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../onboarding/services/model_download_service.dart';

class DownloadedModelsScreen extends StatefulWidget {
  const DownloadedModelsScreen({super.key});

  @override
  State<DownloadedModelsScreen> createState() => _DownloadedModelsScreenState();
}

class _DownloadedModelsScreenState extends State<DownloadedModelsScreen> {
  final _service = ModelDownloadService.instance;
  late Future<List<DownloadedModelInfo>> _modelsFuture;

  ModelVariant? _downloadingVariant;
  DownloadProgress? _activeProgress;
  String? _downloadError;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _modelsFuture = _service.getDownloadedModels();
  }

  Future<void> _confirmDelete(DownloadedModelInfo info) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_forever_rounded, size: 32),
        title: const Text('Delete model?'),
        content: Text(
          'This will permanently remove "${info.variant.displayName}" (${info.sizeLabel}) from your device. You can re-download it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.errorContainer,
              foregroundColor: Theme.of(ctx).colorScheme.onErrorContainer,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _service.deleteModel(info.variant);
    if (mounted) setState(_reload);
  }

  Future<void> _startDownload(ModelVariant variant) async {
    setState(() {
      _downloadingVariant = variant;
      _activeProgress = null;
      _downloadError = null;
    });

    await _service.downloadModel(
      variant: variant,
      onProgress: (p) {
        if (mounted) setState(() => _activeProgress = p);
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _downloadError = e.toString();
            _downloadingVariant = null;
            _activeProgress = null;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _downloadingVariant = null;
        _activeProgress = null;
        _reload();
      });
    }
  }

  void _cancelDownload() {
    _service.cancelDownload();
    setState(() {
      _downloadingVariant = null;
      _activeProgress = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Models'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _downloadingVariant != null
                ? null
                : () => setState(_reload),
          ),
        ],
      ),
      body: FutureBuilder<List<DownloadedModelInfo>>(
        future: _modelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(
              error: snapshot.error.toString(),
              onRetry: () => setState(_reload),
            );
          }

          final downloaded = snapshot.data ?? [];
          final downloadedVariants = downloaded.map((m) => m.variant).toSet();
          final available = ModelVariant.values
              .where((v) => !downloadedVariants.contains(v))
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (downloaded.isNotEmpty) ...[
                const _SectionHeader(title: 'DOWNLOADED'),
                const SizedBox(height: 12),
                for (final info in downloaded) ...[
                  _DownloadedModelCard(
                    info: info,
                    onDelete: () => _confirmDelete(info),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
              ],
              if (available.isNotEmpty) ...[
                const _SectionHeader(title: 'AVAILABLE TO DOWNLOAD'),
                const SizedBox(height: 12),
                for (final variant in available) ...[
                  _AvailableModelCard(
                    variant: variant,
                    isDownloading: _downloadingVariant == variant,
                    isAnyDownloading: _downloadingVariant != null,
                    progress: _downloadingVariant == variant
                        ? _activeProgress
                        : null,
                    onDownload: () => _startDownload(variant),
                    onCancel: _cancelDownload,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
              if (downloaded.isEmpty && available.isEmpty) const _EmptyState(),
              if (_downloadError != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Download failed: $_downloadError',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.outline,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _DownloadedModelCard extends StatelessWidget {
  const _DownloadedModelCard({required this.info, required this.onDelete});

  final DownloadedModelInfo info;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    Icons.memory_rounded,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.variant.displayName,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        info.sizeLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: colorScheme.error,
                  ),
                  tooltip: 'Delete',
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 16,
                  color: colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onLongPress: () {
                      Clipboard.setData(ClipboardData(text: info.path));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Path copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Text(
                      info.path,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailableModelCard extends StatelessWidget {
  const _AvailableModelCard({
    required this.variant,
    required this.isDownloading,
    required this.isAnyDownloading,
    required this.progress,
    required this.onDownload,
    required this.onCancel,
  });

  final ModelVariant variant;
  final bool isDownloading;
  final bool isAnyDownloading;
  final DownloadProgress? progress;
  final VoidCallback onDownload;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final approxGb = (variant.approximateSizeBytes / (1024 * 1024 * 1024))
        .toStringAsFixed(1);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.cloud_download_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        variant.displayName,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        '~$approxGb GB',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              variant.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (isDownloading) ...[
              LinearProgressIndicator(value: progress?.fraction),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    progress == null
                        ? 'Starting...'
                        : '${progress!.receivedLabel} / ${progress!.totalLabel}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (progress?.remainingTimeLabel != null)
                    Text(
                      progress!.remainingTimeLabel!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancel'),
                  onPressed: onCancel,
                ),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download'),
                  onPressed: isAnyDownloading ? null : onDownload,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No models available',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
