import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../study/providers/study_provider.dart';
import '../../study/screens/generate_questions_screen.dart';
import '../../study/screens/session_result_screen.dart';
import '../../study/screens/study_session_screen.dart';
import 'material_content_screen.dart';

class MaterialOptionsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> material;

  const MaterialOptionsScreen({super.key, required this.material});

  @override
  ConsumerState<MaterialOptionsScreen> createState() =>
      _MaterialOptionsScreenState();
}

class _MaterialOptionsScreenState extends ConsumerState<MaterialOptionsScreen> {
  late Map<String, dynamic> _material;

  @override
  void initState() {
    super.initState();
    _material = Map<String, dynamic>.from(widget.material);
    Future.microtask(() {
      ref.read(studyProvider.notifier).loadBundles(_material['id']);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filename =
        _material[DatabaseHelper.columnFilename] as String? ?? 'Material';
    final type = _material[DatabaseHelper.columnType] as String? ?? 'file';
    final studyState = ref.watch(studyProvider);
    final materialId = _material[DatabaseHelper.columnId].toString();
    final isGeneratingThisMaterial =
        studyState.isGenerating &&
        studyState.generatingMaterialId == materialId;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Material'),
        actions: [
          IconButton(
            tooltip: 'Rename material',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _renameMaterial,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _MaterialHero(
            filename: filename,
            type: type,
            bundleCount: studyState.bundles.length,
          ),
          const SizedBox(height: 20),
          Text(
            'Actions',
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            title: 'Generate quiz',
            subtitle: 'Create new questions from selected pages',
            icon: Icons.auto_awesome_rounded,
            color: AppTheme.primary,
            foreground: AppTheme.textLight,
            busy: isGeneratingThisMaterial,
            busyLabel: studyState.generatingProgress ?? 'Generating...',
            onTap: isGeneratingThisMaterial
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          GenerateQuestionsScreen(material: _material),
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            title: 'View content',
            subtitle: 'Browse the parsed excerpts of this material',
            icon: Icons.menu_book_rounded,
            color: AppTheme.secondary,
            foreground: AppTheme.textLight,
            onTap: () async {
              final deleted = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => MaterialContentScreen(material: _material),
                ),
              );
              if (!context.mounted || deleted != true) return;
              Navigator.pop(context);
            },
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
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Quiz history',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${studyState.bundles.length} bundle${studyState.bundles.length == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (studyState.bundles.isEmpty)
            _EmptyBundles()
          else
            for (final bundle in studyState.bundles)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BundleCard(
                  bundle: bundle,
                  sessions:
                      studyState.sessionsByBundle[bundle['id']] ?? const [],
                  onStart: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudySessionScreen(bundle: bundle),
                      ),
                    ).then((_) {
                      ref
                          .read(studyProvider.notifier)
                          .loadBundles(_material['id'].toString());
                    });
                  },
                  onDelete: () {
                    ref
                        .read(studyProvider.notifier)
                        .deleteBundle(_material['id'].toString(), bundle['id']);
                  },
                  onOpenSession: (session) {
                    final questions = (jsonDecode(bundle['questions']) as List)
                        .map((e) => e.toString())
                        .toList();
                    final answers = (jsonDecode(session['answers']) as List)
                        .map((e) => e.toString())
                        .toList();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SessionResultScreen(
                          questions: questions,
                          userAnswers: answers,
                          evaluation: jsonDecode(session['evaluation']),
                        ),
                      ),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _renameMaterial() async {
    final materialId = _material[DatabaseHelper.columnId] as String;
    final currentName =
        _material[DatabaseHelper.columnFilename] as String? ?? '';
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
    if (newName == null || newName == currentName) return;

    await DatabaseHelper.instance.updateMaterialName(materialId, newName);
    if (!mounted) return;
    setState(() {
      _material = {..._material, DatabaseHelper.columnFilename: newName};
    });
  }
}

class _MaterialHero extends StatelessWidget {
  const _MaterialHero({
    required this.filename,
    required this.type,
    required this.bundleCount,
  });

  final String filename;
  final String type;
  final int bundleCount;

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
                child: Icon(_iconForType(type), color: scheme.onPrimary),
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
                      type.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimary.withValues(alpha: 0.9),
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: scheme.onPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.quiz_rounded, color: scheme.onPrimary, size: 18),
                const SizedBox(width: 8),
                Text(
                  '$bundleCount quiz bundle${bundleCount == 1 ? '' : 's'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'docx':
        return Icons.description_rounded;
      case 'jpg':
      case 'png':
        return Icons.image_rounded;
      case 'mp3':
      case 'm4a':
      case 'wav':
        return Icons.audiotrack_rounded;
      default:
        return Icons.menu_book_rounded;
    }
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.foreground,
    required this.onTap,
    this.busy = false,
    this.busyLabel = '',
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color foreground;
  final VoidCallback? onTap;
  final bool busy;
  final String busyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: foreground.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: busy
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: foreground,
                        ),
                      )
                    : Icon(icon, color: foreground, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      busy ? busyLabel : title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground.withValues(alpha: 0.85),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: foreground.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBundles extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.quiz_outlined, size: 42, color: scheme.primary),
          const SizedBox(height: 10),
          Text(
            'No quizzes yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Generate your first quiz to get started.',
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

class _BundleCard extends StatelessWidget {
  const _BundleCard({
    required this.bundle,
    required this.sessions,
    required this.onStart,
    required this.onDelete,
    required this.onOpenSession,
  });

  final Map<String, dynamic> bundle;
  final List<Map<String, dynamic>> sessions;
  final VoidCallback onStart;
  final VoidCallback onDelete;
  final ValueChanged<Map<String, dynamic>> onOpenSession;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final params = jsonDecode(bundle['params']);
    final questions = jsonDecode(bundle['questions']) as List;
    final date = DateTime.fromMillisecondsSinceEpoch(
      bundle['created_at'] as int,
    );

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.quiz_rounded, color: scheme.onPrimaryContainer),
          ),
          title: Text(
            '${questions.length} questions',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                _MiniTag(
                  label: 'Pages ${params['pageFrom']}-${params['pageTo']}',
                  color: scheme.secondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    DateFormat.yMMMd().format(date),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          children: [
            if (sessions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No sessions yet for this bundle.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...sessions.map((session) {
                final sessionDate = DateTime.fromMillisecondsSinceEpoch(
                  session['created_at'] as int,
                );
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.history_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                    title: Text(
                      DateFormat.yMMMd().add_Hm().format(sessionDate),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                    onTap: () => onOpenSession(session),
                  ),
                );
              }),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                  label: Text('Delete', style: TextStyle(color: scheme.error)),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start session'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label, required this.color});
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
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
