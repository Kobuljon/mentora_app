import 'package:flutter/material.dart';

import '../../../core/widgets/brand_logo.dart';
import '../../../navigation/main_screen.dart';
import '../../onboarding/screens/model_setup_screen.dart';
import '../../onboarding/services/model_download_service.dart';

/// Checks whether the AI model is ready and routes to the appropriate screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAndRoute();
  }

  Future<void> _checkAndRoute() async {
    // Give the splash a moment to render before the async work begins.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    final isReady = await ModelDownloadService.instance.isModelReady();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => isReady ? const MainScreen() : const ModelSetupScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MentoraLogo(
              size: 96,
              padding: 12,
              backgroundColor: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            const SizedBox(height: 24),
            Text(
              'Mentora',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 48),
            const MentoraLogoLoader(size: 34),
          ],
        ),
      ),
    );
  }
}
