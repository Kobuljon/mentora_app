import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mentora_app/app.dart';
import 'package:mentora_app/core/services/download_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DownloadNotificationService.instance.initialize();
  runApp(const ProviderScope(child: MyApp()));
}
