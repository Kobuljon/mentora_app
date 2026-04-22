import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DownloadNotificationService {
  DownloadNotificationService._();

  static final DownloadNotificationService instance =
      DownloadNotificationService._();

  static const int _notificationId = 2001;
  static const String _channelId = 'model_downloads';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const macOSSettings = DarwinInitializationSettings();

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: macOSSettings,
      ),
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        'Model downloads',
        description: 'Shows download progress for offline AI models.',
        importance: Importance.low,
      ),
    );
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> showProgress({
    required String title,
    required String body,
    required int progress,
  }) async {
    if (!_initialized) return;

    final clampedProgress = progress.clamp(0, 100);

    await _plugin.show(
      _notificationId,
      '$title $clampedProgress%',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Model downloads',
          channelDescription: 'Shows download progress for offline AI models.',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: 100,
          progress: clampedProgress,
          category: AndroidNotificationCategory.progress,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: false,
          presentSound: false,
        ),
      ),
    );
  }

  Future<void> showCompleted({
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;

    await _plugin.show(
      _notificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Model downloads',
          channelDescription: 'Shows download progress for offline AI models.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> cancel() async {
    await _plugin.cancel(_notificationId);
  }
}
