import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mentora_app/core/theme/app_theme.dart';
import 'package:mentora_app/features/onboarding/screens/splash_screen.dart';
import 'package:mentora_app/features/settings/providers/settings_provider.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Mentora',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      home: const SplashScreen(),
    );
  }
}
