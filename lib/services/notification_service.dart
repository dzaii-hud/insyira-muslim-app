import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: DarwinInitializationSettings(),
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        // Handle notification tap
      },
    );

    // Request permissions for Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    // Request exact alarm permission for Android 12+
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();

    _initialized = true;
  }

  Future<void> schedulePrayerNotifications(PrayerTimes prayerTimes) async {
    final prefs = await SharedPreferences.getInstance();
    final enableAzan = prefs.getBool('enable_azan') ?? true;

    if (!enableAzan) return;

    // Cancel existing notifications
    await _notifications.cancelAll();

    final now = DateTime.now();
    final timezone = tz.local;

    // Schedule for each prayer
    await _schedulePrayer('Subuh', prayerTimes.fajr, now, timezone);
    await _schedulePrayer('Dzuhur', prayerTimes.dhuhr, now, timezone);
    await _schedulePrayer('Ashar', prayerTimes.asr, now, timezone);
    await _schedulePrayer('Maghrib', prayerTimes.maghrib, now, timezone);
    await _schedulePrayer('Isya', prayerTimes.isha, now, timezone);
  }

  Future<void> _schedulePrayer(
    String prayerName,
    DateTime prayerTime,
    DateTime now,
    tz.Location timezone,
  ) async {
    // If prayer time already passed, skip
    if (prayerTime.isBefore(now)) return;

    final scheduledDate = tz.TZDateTime.from(prayerTime, timezone);

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'prayer_reminder',
          'Pengingat Sholat',
          channelDescription: 'Notifikasi waktu sholat',
          importance: Importance.high,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound('adzan'),
          playSound: true,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(sound: 'adzan.mp3'),
    );

    try {
      await _notifications.zonedSchedule(
        prayerName.hashCode,
        'Waktu Sholat $prayerName',
        'Sudah masuk waktu sholat $prayerName',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      // Fallback ke inexact scheduling jika exact alarm tidak diizinkan
      print('Error scheduling notification: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
