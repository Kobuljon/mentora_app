import 'package:flutter/material.dart';
import 'package:mentora_app/core/theme/app_theme.dart';
import 'package:mentora_app/features/chat/screens/chat_screen.dart';
import 'package:mentora_app/features/library/screens/import_materials_screen.dart';
import 'package:mentora_app/features/library/screens/library_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ImportMaterialsScreen()),
          );
        },
      ),
      _HomeAction(
        title: 'Create Quiz',
        subtitle: 'Based on your\nsources.',
        icon: Icons.quiz_outlined,
        cardColor: AppTheme.secondary,
        foregroundColor: AppTheme.textLight,
        iconBackground: const Color(0x33FFFFFF),
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const LibraryScreen()));
        },
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
                Text(
                  'Recent Studies',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 16),
                const _RecentStudiesCard(),
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

class _RecentStudiesCard extends StatelessWidget {
  const _RecentStudiesCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 30),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant),
      ),
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
          const SizedBox(height: 32),
          Text(
            'Your recent documents and chats will\nappear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 16,
              height: 1.18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
