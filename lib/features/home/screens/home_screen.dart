import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mentora_app/core/database/database_helper.dart';
import 'package:mentora_app/core/theme/app_theme.dart';
import 'package:mentora_app/features/chat/screens/chat_screen.dart';
import 'package:mentora_app/features/library/screens/import_materials_screen.dart';
import 'package:mentora_app/features/library/screens/library_screen.dart';
import 'package:mentora_app/features/library/screens/material_options_screen.dart';
import 'package:mentora_app/features/study/screens/study_session_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<Map<String, dynamic>>>? _recentBundlesFuture;

  @override
  void initState() {
    super.initState();
    _refreshRecent();
  }

  void _refreshRecent() {
    setState(() {
      _recentBundlesFuture = DatabaseHelper.instance.getRecentQuestionBundles(
        limit: 5,
      );
    });
  }

  Future<void> _openQuizPicker(BuildContext context) async {
    final materials = await DatabaseHelper.instance.getAllMaterials();
    if (!context.mounted) return;
    final processed = materials
        .where(
          (m) => (m[DatabaseHelper.columnStatus] ?? 'processed') == 'processed',
        )
        .toList();

    if (processed.isEmpty) {
      Navigator.of(context)
          .push(
            MaterialPageRoute(builder: (_) => const ImportMaterialsScreen()),
          )
          .then((_) => _refreshRecent());
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final scheme = theme.colorScheme;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose a material',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pick a source to generate a new quiz from.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: processed.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final m = processed[i];
                      return Material(
                        color: scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        MaterialOptionsScreen(material: m),
                                  ),
                                )
                                .then((_) => _refreshRecent());
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: scheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.menu_book_outlined,
                                    color: scheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m[DatabaseHelper.columnFilename]
                                                ?.toString() ??
                                            'Untitled',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: scheme.onSurface,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        (m[DatabaseHelper.columnType] ?? '')
                                            .toString()
                                            .toUpperCase(),
                                        style: TextStyle(
                                          color: scheme.onSurfaceVariant,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (mounted) _refreshRecent();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final actions = <_HomeAction>[
      _HomeAction(
        title: 'Upload &\nAnalyze PDF',
        subtitle: 'Local, private,\nand smart.',
        icon: Icons.note_add_outlined,
        cardColor: AppTheme.primary,
        foregroundColor: AppTheme.textLight,
        iconBackground: const Color(0x33FFFFFF),
        onTap: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) => const ImportMaterialsScreen(),
                ),
              )
              .then((_) => _refreshRecent());
        },
      ),
      _HomeAction(
        title: 'Start a\nQuiz',
        subtitle: 'Pick a source,\nbegin in one tap.',
        icon: Icons.quiz_outlined,
        cardColor: AppTheme.secondary,
        foregroundColor: AppTheme.textLight,
        iconBackground: const Color(0x33FFFFFF),
        onTap: () => _openQuizPicker(context),
      ),
      _HomeAction(
        title: 'Ask your\nTutor',
        subtitle: 'Direct chat\ninterface.',
        icon: Icons.chat_bubble_outline_rounded,
        cardColor: AppTheme.accent,
        // Lime card needs dark text for contrast.
        foregroundColor: AppTheme.textDark,
        iconBackground: const Color(0x22000000),
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
        },
      ),
    ];

    final gradientColors = isDark
        ? const [AppTheme.cardDark, AppTheme.backgroundDark]
        : const [Color(0xFFF2EEF9), AppTheme.backgroundLight];

    return Scaffold(
      backgroundColor: scheme.surface,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HeroCard(),
                const SizedBox(height: 30),
                Text(
                  'Get Started',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 14.0;
                    final crossAxisCount = constraints.maxWidth >= 360 ? 3 : 2;
                    final tileWidth =
                        (constraints.maxWidth -
                            (spacing * (crossAxisCount - 1))) /
                        crossAxisCount;

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (final action in actions)
                          SizedBox(
                            width: tileWidth,
                            child: _QuickActionCard(action: action),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Recent Quizzes',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _openQuizPicker(context),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'New quiz',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _RecentQuizzesSection(
                  future: _recentBundlesFuture,
                  onChanged: _refreshRecent,
                  onBrowseLibrary: () {
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) => const LibraryScreen(),
                          ),
                        )
                        .then((_) => _refreshRecent());
                  },
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => _showSampleGuide(context),
                    child: const Text(
                      'Show Guide',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationThickness: 1.6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 44,
                    color: scheme.primary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSampleGuide(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Start Guide',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              const _GuideStep(
                step: '01',
                title: 'Import your material',
                subtitle:
                    'Upload a PDF, image, or audio file and let Mentora extract the important study content.',
              ),
              const SizedBox(height: 14),
              const _GuideStep(
                step: '02',
                title: 'Generate practice from it',
                subtitle:
                    'Use your saved sources in the library to create quizzes and study sessions around the exact topic.',
              ),
              const SizedBox(height: 14),
              const _GuideStep(
                step: '03',
                title: 'Ask follow-up questions',
                subtitle:
                    'Open the tutor chat when you want explanations, summaries, or revision help.',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, Color(0xFF4C1D95)],
        ),
        borderRadius: BorderRadius.circular(28),
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
                  'Welcome to your\nAI Tutor!',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your local agent is ready to help.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.85),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const _TutorBadge(),
        ],
      ),
    );
  }
}

class _TutorBadge extends StatelessWidget {
  const _TutorBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 94,
      height: 94,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.22),
                  Colors.white.withValues(alpha: 0.06),
                ],
              ),
            ),
          ),
          const Icon(
            Icons.smart_toy_outlined,
            size: 44,
            color: AppTheme.textLight,
          ),
          Positioned(
            top: 8,
            child: Transform.rotate(
              angle: -0.18,
              child: const Icon(
                Icons.school_rounded,
                size: 36,
                color: AppTheme.textLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action});

  final _HomeAction action;

  @override
  Widget build(BuildContext context) {
    final fg = action.foregroundColor;
    return SizedBox(
      height: 178,
      child: Material(
        color: action.cardColor,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: action.iconBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(action.icon, color: fg, size: 28),
                ),
                const Spacer(),
                Text(
                  action.title,
                  style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  action.subtitle,
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.78),
                    fontSize: 11.8,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentQuizzesSection extends StatelessWidget {
  const _RecentQuizzesSection({
    required this.future,
    required this.onChanged,
    required this.onBrowseLibrary,
  });

  final Future<List<Map<String, dynamic>>>? future;
  final VoidCallback onChanged;
  final VoidCallback onBrowseLibrary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _emptyShell(
            scheme,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final bundles = (snapshot.data ?? []).where((b) {
          try {
            final qs = jsonDecode(b['questions']?.toString() ?? '[]');
            return qs is List && qs.isNotEmpty;
          } catch (_) {
            return false;
          }
        }).toList();

        if (bundles.isEmpty) {
          return _emptyShell(
            scheme,
            child: Column(
              children: [
                Container(
                  width: 140,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'No quizzes yet.\nGenerate one from a material to start practicing.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 15,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onBrowseLibrary,
                  icon: const Icon(Icons.library_books_outlined),
                  label: const Text('Open library'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            for (final b in bundles) ...[
              _RecentQuizCard(bundle: b, onChanged: onChanged),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _emptyShell(ColorScheme scheme, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _RecentQuizCard extends StatelessWidget {
  const _RecentQuizCard({required this.bundle, required this.onChanged});

  final Map<String, dynamic> bundle;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final filename =
        bundle['material_filename']?.toString() ?? 'Untitled material';
    final createdAtMs = bundle['created_at'] as int?;
    final createdAt = createdAtMs != null
        ? DateFormat.yMMMd().add_Hm().format(
            DateTime.fromMillisecondsSinceEpoch(createdAtMs),
          )
        : '';
    int questionCount = 0;
    try {
      final qs = jsonDecode(bundle['questions']?.toString() ?? '[]');
      if (qs is List) questionCount = qs.length;
    } catch (_) {}

    String pageRange = '';
    try {
      final params = jsonDecode(bundle['params']?.toString() ?? '{}');
      if (params is Map) {
        final from = params['pageFrom'];
        final to = params['pageTo'];
        if (from != null && to != null) {
          pageRange = from == to ? 'Page $from' : 'Pages $from\u2013$to';
        }
      }
    } catch (_) {}

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) => StudySessionScreen(bundle: bundle),
                ),
              )
              .then((_) => onChanged());
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.quiz_outlined,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        '$questionCount question${questionCount == 1 ? '' : 's'}',
                        if (pageRange.isNotEmpty) pageRange,
                        if (createdAt.isNotEmpty) createdAt,
                      ].join('  •  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) => StudySessionScreen(bundle: bundle),
                        ),
                      )
                      .then((_) => onChanged());
                },
                child: const Text('Start'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  final String step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            step,
            style: TextStyle(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeAction {
  const _HomeAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.cardColor,
    required this.foregroundColor,
    required this.iconBackground,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color cardColor;
  final Color foregroundColor;
  final Color iconBackground;
  final VoidCallback onTap;
}
