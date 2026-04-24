import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../navigation/main_screen.dart';
import '../../onboarding/providers/model_setup_provider.dart';
import '../../onboarding/services/model_download_service.dart';

class ModelSetupScreen extends ConsumerWidget {
  const ModelSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(modelSetupProvider);
    final notifier = ref.read(modelSetupProvider.notifier);

    // Navigate to HomeScreen once download is complete.
    ref.listen<ModelSetupState>(modelSetupProvider, (_, next) {
      if (next.phase == SetupPhase.complete) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (_) => false,
        );
      }
    });

    // Wifi warning dialog.
    if (state.wifiWarning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWifiWarning(context, notifier);
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: switch (state.phase) {
            SetupPhase.selection => _SelectionView(notifier: notifier),
            SetupPhase.downloading => _DownloadingView(
              state: state,
              notifier: notifier,
            ),
            SetupPhase.error => _ErrorView(
              message: state.errorMessage ?? 'An unknown error occurred.',
              onRetry: notifier.retryFromError,
            ),
            SetupPhase.complete => const _CompletionView(),
          },
        ),
      ),
    );
  }

  void _showWifiWarning(BuildContext context, ModelSetupNotifier notifier) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.wifi_off_rounded, size: 40),
        title: const Text('No Wi-Fi Detected'),
        content: const Text(
          'You\'re on mobile data. Downloading the AI model will use 2–4 GB of your data plan. '
          'We recommend connecting to Wi-Fi first.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              notifier.dismissWifiWarning();
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              notifier.confirmCellularDownload();
            },
            child: const Text('Download Anyway'),
          ),
        ],
      ),
    );
  }
}

// ── Selection View ─────────────────────────────────────────────────────────────

class _SelectionView extends StatelessWidget {
  const _SelectionView({required this.notifier});

  final ModelSetupNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          '👋 Welcome to Mentora!',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'To get started, we need to download the AI brain that powers your lessons. '
          'This only happens once and requires 2–4 GB of storage.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 40),
        Text(
          'Choose your engine:',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _EngineCard(
          icon: Icons.bolt_rounded,
          title: 'Standard Engine',
          subtitle: 'Recommended',
          description: 'Fast and lightweight. Great for everyday practice.',
          badge: '~2 GB',
          badgeColor: colorScheme.primaryContainer,
          badgeTextColor: colorScheme.onPrimaryContainer,
          onTap: () => notifier.startDownload(ModelVariant.e2b),
        ),
        const SizedBox(height: 16),
        _EngineCard(
          icon: Icons.auto_awesome_rounded,
          title: 'Advanced Engine',
          subtitle: 'More accurate',
          description: 'Deeper explanations and richer feedback.',
          badge: '~4 GB',
          badgeColor: colorScheme.tertiaryContainer,
          badgeTextColor: colorScheme.onTertiaryContainer,
          onTap: () => notifier.startDownload(ModelVariant.e4b),
        ),
        const SizedBox(height: 16),
        _EngineCard(
          icon: Icons.image_search_rounded,
          title: 'Multimodal Engine',
          subtitle: 'Text + Images',
          description:
              'Supports image upload. Required for vision-based features.',
          badge: '~3 GB',
          badgeColor: colorScheme.secondaryContainer,
          badgeTextColor: colorScheme.onSecondaryContainer,
          onTap: () => notifier.startDownload(ModelVariant.e2bMultimodal),
        ),
        const Spacer(),
        Row(
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Everything stays on your device. No data is sent to the cloud.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EngineCard extends StatelessWidget {
  const _EngineCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.badge,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final String badge;
  final Color badgeColor;
  final Color badgeTextColor;
  final VoidCallback onTap;

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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            subtitle,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: badgeTextColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                badge,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Downloading View ───────────────────────────────────────────────────────────

class _DownloadingView extends StatelessWidget {
  const _DownloadingView({required this.state, required this.notifier});

  final ModelSetupState state;
  final ModelSetupNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = state.progress;
    final fraction = progress?.fraction ?? 0.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 160,
              height: 160,
              child: CircularProgressIndicator(
                value: fraction > 0 ? fraction : null,
                strokeWidth: 10,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: colorScheme.primary,
              ),
            ),
            Text(
              '${(fraction * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text(
          'Downloading AI Model…',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (progress != null)
          Text(
            'Downloaded ${progress.receivedLabel} / ${progress.totalLabel}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        if (progress?.remainingTimeLabel != null) ...[
          const SizedBox(height: 8),
          Text(
            'About ${progress!.remainingTimeLabel}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          state.selectedVariant?.displayName ?? '',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 48),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.screen_lock_portrait_outlined,
              size: 16,
              color: colorScheme.onSurface.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 6),
            Text(
              'Keep app open for best results',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        TextButton(
          onPressed: notifier.cancelDownload,
          child: const Text('Cancel Download'),
        ),
      ],
    );
  }
}

// ── Error View ─────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.cloud_off_rounded,
          size: 64,
          color: colorScheme.errorContainer,
        ),
        const SizedBox(height: 24),
        Text(
          'Something went wrong',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try Again'),
        ),
      ],
    );
  }
}

// ── Completion View ────────────────────────────────────────────────────────────

class _CompletionView extends StatelessWidget {
  const _CompletionView();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 80,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'All done!',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Opening Mentora…'),
        ],
      ),
    );
  }
}
