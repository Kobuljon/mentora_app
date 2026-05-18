import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../study/providers/study_provider.dart';
import 'import_materials_screen.dart';
import 'material_options_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  List<Map<String, dynamic>> _materials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() => _isLoading = true);
    await DatabaseHelper.instance.markAllProcessingMaterialsAsFailed();
    final materials = await DatabaseHelper.instance.getAllMaterials();
    if (!mounted) return;
    setState(() {
      _materials = materials;
      _isLoading = false;
    });
  }

  Future<void> _openImport() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImportMaterialsScreen()),
    );
    if (!mounted) return;
    _loadMaterials();
  }

  Future<void> _renameMaterial(Map<String, dynamic> material) async {
    final materialId = material[DatabaseHelper.columnId] as String?;
    if (materialId == null || materialId.isEmpty) return;

    final currentName =
        material[DatabaseHelper.columnFilename] as String? ?? 'Material';
    final controller = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename material'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Material name'),
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
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (!mounted || newName == null || newName == currentName) return;

    await DatabaseHelper.instance.updateMaterialName(materialId, newName);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Material renamed')));
    _loadMaterials();
  }

  Future<void> _deleteMaterial(Map<String, dynamic> material) async {
    final materialId = material[DatabaseHelper.columnId] as String?;
    if (materialId == null || materialId.isEmpty) return;

    final currentName =
        material[DatabaseHelper.columnFilename] as String? ?? 'Material';

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: const Text('Delete material?'),
          content: Text(
            'Delete "$currentName" and all of its excerpts and quiz history?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.errorContainer,
                foregroundColor: scheme.onErrorContainer,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) return;

    ref.read(studyProvider.notifier).cancelGenerationForMaterial(materialId);
    await DatabaseHelper.instance.deleteMaterial(materialId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Material deleted')));
    await _loadMaterials();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadMaterials,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: MentoraLogoLoader(size: 34))
          : RefreshIndicator(
              onRefresh: _loadMaterials,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  _LibraryHero(count: _materials.length, onImport: _openImport),
                  const SizedBox(height: 20),
                  if (_materials.isEmpty)
                    _EmptyState(onImport: _openImport)
                  else ...[
                    Text(
                      'Your materials',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final material in _materials)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MaterialCard(
                          material: material,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    MaterialOptionsScreen(material: material),
                              ),
                            );
                            if (!mounted) return;
                            _loadMaterials();
                          },
                          onRename: () => _renameMaterial(material),
                          onDelete: () => _deleteMaterial(material),
                        ),
                      ),
                  ],
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openImport,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add material'),
      ),
    );
  }
}

class _LibraryHero extends StatelessWidget {
  const _LibraryHero({required this.count, required this.onImport});

  final int count;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 18, 20),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Library',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count == 0
                      ? 'No materials yet'
                      : '$count material${count == 1 ? '' : 's'} saved',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onImport,
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('Import'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.textDark,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: scheme.onPrimary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: MentoraLogo(size: 60, padding: 10),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const MentoraLogo(size: 64, padding: 12),
          ),
          const SizedBox(height: 16),
          Text(
            'Your library is empty',
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Import a PDF, image, document, or audio file to get started.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add your first material'),
          ),
        ],
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({
    required this.material,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final Map<String, dynamic> material;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final status =
        material[DatabaseHelper.columnStatus] as String? ?? 'processing';
    final type = material[DatabaseHelper.columnType] as String? ?? 'unknown';
    final filename =
        material[DatabaseHelper.columnFilename] as String? ?? 'Unknown';

    final typeMeta = _typeMeta(type);

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: typeMeta.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(typeMeta.icon, color: typeMeta.foreground),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          type.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: scheme.onSurfaceVariant,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(status: status),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: scheme.onSurfaceVariant,
                ),
                onSelected: (value) {
                  if (value == 'rename') onRename();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: 'rename',
                    child: Text('Rename'),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  _TypeMeta _typeMeta(String type) {
    switch (type) {
      case 'pdf':
        return const _TypeMeta(
          icon: Icons.picture_as_pdf_rounded,
          background: Color(0x33DC2626),
          foreground: Color(0xFFDC2626),
        );
      case 'docx':
        return _TypeMeta(
          icon: Icons.description_rounded,
          background: AppTheme.secondary.withValues(alpha: 0.18),
          foreground: AppTheme.secondary,
        );
      case 'jpg':
      case 'png':
        return _TypeMeta(
          icon: Icons.image_rounded,
          background: AppTheme.accent.withValues(alpha: 0.22),
          foreground: const Color(0xFF4D7C0F),
        );
      case 'mp3':
      case 'm4a':
      case 'wav':
        return _TypeMeta(
          icon: Icons.audio_file_rounded,
          background: AppTheme.primary.withValues(alpha: 0.18),
          foreground: AppTheme.primary,
        );
      default:
        return const _TypeMeta(
          icon: Icons.insert_drive_file_rounded,
          background: Color(0x22A1A1AA),
          foreground: Color(0xFF52525B),
        );
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    late final Color bg;
    late final Color fg;
    late final String label;
    Widget? leading;

    switch (status) {
      case 'processing':
        bg = scheme.secondary.withValues(alpha: 0.16);
        fg = scheme.secondary;
        label = 'Processing';
        leading = SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            valueColor: AlwaysStoppedAnimation<Color>(fg),
          ),
        );
        break;
      case 'failed':
        bg = scheme.error.withValues(alpha: 0.16);
        fg = scheme.error;
        label = 'Failed';
        leading = Icon(Icons.error_outline_rounded, size: 12, color: fg);
        break;
      case 'completed':
      default:
        bg = AppTheme.accent.withValues(alpha: 0.22);
        fg = const Color(0xFF3F6E0A);
        label = 'Ready';
        leading = Icon(Icons.check_circle_rounded, size: 12, color: fg);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeMeta {
  const _TypeMeta({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
}
