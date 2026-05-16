import 'dart:math' as math;

import 'dart:math' as math;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mentora_app/features/chat/screens/chat_screen.dart';
import 'package:mentora_app/features/library/screens/import_materials_screen.dart';
import 'package:mentora_app/features/library/screens/library_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _pageBackground = Color(0xFF141119);
  static const _heroTop = Color(0xFF2A2431);
  static const _heroBottom = Color(0xFF211D27);
  static const _panelColor = Color(0xFFF2EFF4);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final actions = [
      _HomeAction(
        title: 'Upload &\nAnalyze PDF',
        subtitle: 'Local, private,\nand smart.',
        icon: Icons.note_add_outlined,
        cardColor: const Color(0xFF2A2436),
        iconColor: const Color(0xFFD9C8FF),
        iconBackground: const Color(0xFF4A3E5B),
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
        cardColor: const Color(0xFF3A3027),
        iconColor: const Color(0xFFFFD28E),
        iconBackground: const Color(0xFF6B5840),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LibraryScreen()),
          );
        },
      ),
      _HomeAction(
        title: 'Ask your\nTutor',
        subtitle: 'Direct chat\ninterface.',
        icon: Icons.chat_bubble_outline_rounded,
        cardColor: const Color(0xFF223630),
        iconColor: const Color(0xFF9EF1C8),
        iconBackground: const Color(0xFF35594F),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ChatScreen()),
          );
        },
      ),
    ];

    return Scaffold(
      backgroundColor: _pageBackground,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B1720), _pageBackground],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroCard(theme: theme),
                const SizedBox(height: 30),
                Text(
                  'Get Started',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
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
                        (constraints.maxWidth - (spacing * (crossAxisCount - 1))) /
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
                    color: Colors.white,
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
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE9E0F1),
                    ),
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
                const Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 44,
                    color: Color(0xFFF0E7FF),
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
      backgroundColor: const Color(0xFF1E1924),
      showDragHandle: true,
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Start Guide',
                style: textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              const _GuideStep(
                step: '01',
                title: 'Import your material',
                subtitle: 'Upload a PDF, image, or audio file and let Mentora extract the important study content.',
              ),
              const SizedBox(height: 14),
              const _GuideStep(
                step: '02',
                title: 'Generate practice from it',
                subtitle: 'Use your saved sources in the library to create quizzes and study sessions around the exact topic.',
              ),
              const SizedBox(height: 14),
              const _GuideStep(
                step: '03',
                title: 'Ask follow-up questions',
                subtitle: 'Open the tutor chat when you want explanations, summaries, or revision help.',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HomeScreen._heroTop, HomeScreen._heroBottom],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 12),
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
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your local agent is ready to help.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFFD0C7D9),
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
                  Colors.white.withValues(alpha: 0.2),
                  Colors.white.withValues(alpha: 0.06),
                ],
              ),
            ),
          ),
          const Icon(
            Icons.smart_toy_outlined,
            size: 44,
            color: Color(0xFFE9E0F2),
          ),
          Positioned(
            top: 8,
            child: Transform.rotate(
              angle: -0.18,
              child: const Icon(
                Icons.school_rounded,
                size: 36,
                color: Color(0xFFE9E0F2),
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
                  child: Icon(action.icon, color: action.iconColor, size: 28),
                ),
                const Spacer(),
                Text(
                  action.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  action.subtitle,
                  style: const TextStyle(
                    color: Color(0xFFD4CDD9),
                    fontSize: 11.8,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 30),
      decoration: BoxDecoration(
        color: HomeScreen._panelColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Container(
            width: 140,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFD9D5DC),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Your recent documents and chats will\nappear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF7C7485),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF342B40),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            step,
            style: const TextStyle(
              color: Color(0xFFE9E0F2),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFFD0C7D8),
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
    required this.iconColor,
    required this.iconBackground,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color cardColor;
  final Color iconColor;
  final Color iconBackground;
  final VoidCallback onTap;
}
