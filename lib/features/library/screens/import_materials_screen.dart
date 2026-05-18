import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_logo.dart';
import '../services/local_test_materials_service.dart';
import '../services/material_processor_service.dart';

class ImportMaterialsScreen extends ConsumerStatefulWidget {
  const ImportMaterialsScreen({super.key});

  @override
  ConsumerState<ImportMaterialsScreen> createState() =>
      _ImportMaterialsScreenState();
}

class _ImportMaterialsScreenState extends ConsumerState<ImportMaterialsScreen> {
  bool _isImporting = false;
  late final Future<List<LocalTestMaterialFile>> _localTestFilesFuture;
  String _importStatus = '';
  double _importProgress = 0.0;

  static const List<_FormatSpec> _formats = [
    _FormatSpec('PDF', Icons.picture_as_pdf_rounded, Color(0xFFDC2626)),
    _FormatSpec('DOCX', Icons.description_rounded, AppTheme.secondary),
    _FormatSpec('Image', Icons.image_rounded, AppTheme.accent),
    _FormatSpec('Audio', Icons.audiotrack_rounded, AppTheme.primary),
  ];

  @override
  void initState() {
    super.initState();
    _localTestFilesFuture = LocalTestMaterialsService.instance.listFiles();
  }

  Future<void> _pickAndProcessFile() async {
    if (_isImporting) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'mp3', 'm4a', 'wav', 'jpg', 'png'],
    );

    if (!mounted || result == null) return;
    final picked = result.files.single;
    final pickedPath = picked.path;
    if (pickedPath == null || pickedPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not read the selected file path. Try another file.',
          ),
        ),
      );
      return;
    }

    await _processSelectedFile(pickedPath, picked.name);
  }

  Future<void> _processLocalTestFile(LocalTestMaterialFile file) async {
    if (_isImporting) return;

    final tempPath = await LocalTestMaterialsService.instance
        .materializeToTempFile(file);
    if (!mounted) return;
    await _processSelectedFile(tempPath, file.name);
  }

  Future<void> _processSelectedFile(String filePath, String fileName) async {
    if (_isImporting) return;

    final displayName = await _askForMaterialName(fileName);
    if (displayName == null || !mounted) return;

    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    setState(() {
      _isImporting = true;
      _importStatus = 'Preparing $displayName...';
      _importProgress = 0.1;
    });

    var importSucceeded = false;
    try {
      await MaterialProcessorService.instance.processFile(
        filePath,
        displayName: displayName,
        onProgress: (status, progress) {
          if (!mounted) return;
          setState(() {
            _importStatus = status;
            _importProgress = progress;
          });
        },
      );
      importSucceeded = true;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }

    if (importSucceeded && mounted) {
      setState(() {
        _importStatus = 'Import complete';
        _importProgress = 1.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Material imported successfully')),
      );
      Navigator.pop(context);
    }
  }

  Future<String?> _askForMaterialName(String filename) async {
    final defaultName = filename.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final controller = TextEditingController(text: defaultName);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Name this material'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Material name',
                helperText: filename,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a name';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dialogContext, controller.text.trim());
              },
              child: const Text('Import'),
            ),
          ],
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: const Text('Import Material')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _ImportHero(),
            const SizedBox(height: 20),
            if (_isImporting)
              _ProgressCard(status: _importStatus, progress: _importProgress)
            else ...[
              Text(
                'Supported formats',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              _FormatGrid(formats: _formats),
              const SizedBox(height: 20),
              _DropZone(onTap: _pickAndProcessFile),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _pickAndProcessFile,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Browse files'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 18),
              _LocalTestFilesSection(
                filesFuture: _localTestFilesFuture,
                onImport: _processLocalTestFile,
              ),
              const SizedBox(height: 14),
              _TipCard(),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImportHero extends StatelessWidget {
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.onPrimary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const MentoraLogo(size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add a study material',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Import a document, image, or audio file to start studying.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatSpec {
  const _FormatSpec(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class _FormatGrid extends StatelessWidget {
  const _FormatGrid({required this.formats});
  final List<_FormatSpec> formats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        for (int i = 0; i < formats.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: formats[i].color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      formats[i].icon,
                      color: formats[i].color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    formats[i].label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DropZone extends StatelessWidget {
  const _DropZone({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.4),
              width: 1.4,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.upload_file_rounded,
                  color: scheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tap to select a file',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'PDF, DOCX, JPG, PNG, MP3, M4A, WAV',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.status, required this.progress});
  final String status;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Importing material',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).clamp(0, 100).round()}%',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress > 0 ? progress.clamp(0, 1) : null,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHigh,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            status,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_rounded,
            color: Color(0xFF3F6E0A),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tip: clear, high-contrast scans and well-formatted PDFs produce the best questions.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.brightness == Brightness.dark
                    ? scheme.onSurface
                    : const Color(0xFF1A2E05),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalTestFilesSection extends StatelessWidget {
  const _LocalTestFilesSection({
    required this.filesFuture,
    required this.onImport,
  });

  final Future<List<LocalTestMaterialFile>> filesFuture;
  final ValueChanged<LocalTestMaterialFile> onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return FutureBuilder<List<LocalTestMaterialFile>>(
      future: filesFuture,
      builder: (context, snapshot) {
        final files = snapshot.data ?? const <LocalTestMaterialFile>[];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Local/TEST files',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Drop reusable test materials into the project folder ${LocalTestMaterialsService.folderPath} and they show up here after a restart.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (files.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Text(
                    'No local test files found yet.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    for (int i = 0; i < files.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _LocalTestFileTile(
                        file: files[i],
                        onImport: () => onImport(files[i]),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LocalTestFileTile extends StatelessWidget {
  const _LocalTestFileTile({required this.file, required this.onImport});

  final LocalTestMaterialFile file;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final icon = switch (file.extension) {
      '.pdf' => Icons.picture_as_pdf_rounded,
      '.docx' => Icons.description_rounded,
      '.jpg' || '.png' => Icons.image_rounded,
      '.mp3' || '.m4a' || '.wav' => Icons.audiotrack_rounded,
      _ => Icons.insert_drive_file_rounded,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  file.typeLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonal(onPressed: onImport, child: const Text('Import')),
        ],
      ),
    );
  }
}
