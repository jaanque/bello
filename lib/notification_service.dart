// lib/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = "bello_reminders";
  static const String _channelName = "Bello Daily Reminders";
  static const String _channelDescription = "Reminders to record daily videos";
  static const int _dailyReminderNotificationId = 0;

  static Future<void> initialize() async {
    // Initialize timezone database
    tz.initializeTimeZones();
    // Set the local timezone (optional, but good for accuracy if known)
    // tz.setLocalLocation(tz.getLocation('America/New_York')); // Example

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Default app icon

    // Add iOS Initialization settings if targeting iOS
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: onDidReceiveLocalNotification,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    // Request permissions for Android 13+
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();
     // For iOS, permission is requested during initializationSettingsIOS if needed
  }

  static void onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) async {
    // Handle notification tapped logic when app is in foreground for older iOS versions
    print('onDidReceiveLocalNotification: id $id, title $title, body $body, payload $payload');
  }

  static void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) async {
    // Handle notification tapped logic (app is opened from notification)
    final String? payload = notificationResponse.payload;
    if (notificationResponse.payload != null) {
      print('Notification payload: $payload');
    }
    // Example: Navigate to a specific screen
    // await Navigator.push(context, MaterialPageRoute<void>(builder: (context) => SecondScreen(payload)));
  }

  static Future<void> scheduleDailyReminderNotification() async {
    await _notificationsPlugin.zonedSchedule(
      _dailyReminderNotificationId,
      'Bello',
      '¡No olvides grabar tu recuerdo de hoy!',
      _nextInstanceOf8PM(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher', // Ensure this icon exists
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily at this time
      payload: 'daily_reminder',
    );
    print("Daily reminder scheduled for 8 PM.");
  }

  // Original method
  static tz.TZDateTime _nextInstanceOf8PM() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    return _calculateNext8PM(now);
  }

  // Extracted logic for testability
  static tz.TZDateTime _calculateNext8PM(tz.TZDateTime forDateTime) {
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, forDateTime.year, forDateTime.month, forDateTime.day, 20); // 8 PM
    if (scheduledDate.isBefore(forDateTime)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // Test helper that uses the extracted logic (can be called from tests)
  static tz.TZDateTime testNextInstanceOf8PM(tz.TZDateTime customNow) {
    return _calculateNext8PM(customNow);
  }

  static Future<void> cancelDailyReminderNotification() async {
    await _notificationsPlugin.cancel(_dailyReminderNotificationId);
    print("Daily reminder notification cancelled.");
  }

  static Future<void> checkAndRescheduleDailyReminder() async {
    // This function could be called daily (e.g. using a background process or on app open)
    // to ensure the notification is always scheduled for the *next* 8 PM.
    // The current zonedSchedule with matchDateTimeComponents.time should handle daily repetition.
    // However, explicit re-scheduling after it fires or on app start can be more robust.
    // For now, we rely on matchDateTimeComponents and schedule it once.
    // If the app is consistently opened daily, scheduling on load might be enough.
    print("Checking and re-scheduling daily reminder (if needed).");
    await cancelDailyReminderNotification(); // Cancel any existing to avoid duplicates if logic changes
    await scheduleDailyReminderNotification();
  }
}
