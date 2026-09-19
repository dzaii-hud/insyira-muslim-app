import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service terpusat untuk seluruh notifikasi Insyira Muslim App.
///
/// Ada 2 jenis notifikasi:
///
/// 1. **Notifikasi Adzan**
///    Dijadwalkan tepat pada menit masuknya waktu sholat memakai
///    `AndroidScheduleMode.alarmClock` (setara alarm bawaan Android) sehingga
///    suara adzan tetap diputar **walaupun aplikasi sedang tidak dibuka**,
///    bahkan saat HP dalam mode Doze / hemat baterai.
///    Suara diambil dari file native `android/app/src/main/res/raw/adzan.mp3`.
///
/// 2. **Notifikasi Dzikir**
///    Ditampilkan langsung (instant) ketika user menyelesaikan dzikir
///    pagi / sore.
///
/// ⚠️ PENTING: Android "mengunci" konfigurasi suara pada sebuah notification
/// channel saat channel dibuat pertama kali. Karena itu, kalau file suara adzan
/// diganti, WAJIB menaikkan versi [azanChannelId] (contoh: `azan_channel_v3`),
/// kalau tidak HP user masih akan memakai suara lama.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // ======================= KONFIGURASI CHANNEL =======================
  static const String azanChannelId = 'azan_channel_v2';
  static const String dzikirChannelId = 'dzikir_channel_v1';

  /// Nama file native tanpa ekstensi di `android/app/src/main/res/raw/`.
  static const String _azanRawSound = 'adzan';

  /// Nama file suara untuk iOS (harus ditambahkan ke bundle Xcode).
  static const String _azanIosSound = 'adzan.mp3';

  static const String _azanChannelName = 'Suara Adzan';
  static const String _azanChannelDesc = 'Adzan saat masuk waktu sholat';
  static const String _dzikirChannelName = 'Dzikir Harian';
  static const String _dzikirChannelDesc =
      'Notifikasi setelah kamu menyelesaikan dzikir';

  /// ID notifikasi adzan agar stabil (tidak berubah-ubah seperti hashCode).
  static const Map<String, int> _prayerNotificationIds = {
    'Subuh': 1101,
    'Dzuhur': 1102,
    'Ashar': 1103,
    'Maghrib': 1104,
    'Isya': 1105,
  };

  /// ID notifikasi penyelesaian dzikir.
  static const int _dzikirPagiNotificationId = 2101;
  static const int _dzikirSoreNotificationId = 2102;

  /// ID untuk tombol "Tes Adzan" di halaman pengaturan.
  static const int _testAzanNotificationId = 2999;

  /// Key SharedPreferences untuk menyimpan jadwal sholat terakhir.
  static const String _prayerTimesKey = 'saved_prayer_times';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Notifikasi lokal HANYA tersedia di Android & iOS.
  ///
  /// `flutter_local_notifications` tidak punya implementasi web, jadi kalau
  /// dipanggil dari browser akan melempar error. Di web, adzan & notifikasi
  /// dzikir memang tidak bisa dijadwalkan (butuh Web Push + service worker,
  /// itu pekerjaan terpisah).
  static bool get isSupported => !kIsWeb;

  /// Dipanggil ketika user menekan salah satu notifikasi.
  /// [payload] berisi penanda, contoh: `prayer:Subuh` atau `dzikir:pagi`.
  void Function(String? payload)? onNotificationTap;

  // ===================================================================
  // INISIALISASI
  // ===================================================================
  Future<void> init() async {
    if (!isSupported) return;
    if (_initialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        onNotificationTap?.call(response.payload);
      },
    );

    // Buat channel secara eksplisit supaya suara adzan PASTI terpasang,
    // bukan menunggu pembuatan otomatis saat notifikasi pertama dijadwalkan.
    await _createChannels();

    // ==== Izin Android 13+ (POST_NOTIFICATIONS) ====
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    try {
      await android?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Gagal meminta izin notifikasi: $e');
    }

    // ==== Izin exact alarm Android 12+ (wajib agar adzan tepat waktu) ====
    try {
      await android?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('Gagal meminta izin exact alarm: $e');
    }

    // ==== Izin iOS ====
    try {
      await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('Gagal meminta izin notifikasi iOS: $e');
    }

    _initialized = true;
  }

  Future<void> _createChannels() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    // Channel adzan: pentingnya MAX + suara file adzan mp3 + atribut alarm.
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        azanChannelId,
        _azanChannelName,
        description: _azanChannelDesc,
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_azanRawSound),
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );

    // Channel dzikir: pentingnya HIGH supaya muncul sebagai heads-up banner.
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        dzikirChannelId,
        _dzikirChannelName,
        description: _dzikirChannelDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  /// Berguna untuk memastikan izin & channel benar-benar siap.
  /// Dipakai halaman pengaturan sebelum tombol "Tes Adzan".
  Future<bool> ensureReady() async {
    if (!isSupported) return false;
    await init();
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;

    final enabled = await android.areNotificationsEnabled() ?? true;
    if (!enabled) {
      await android.requestNotificationsPermission();
    }
    try {
      await android.requestExactAlarmsPermission();
    } catch (_) {}
    return enabled;
  }

  // ===================================================================
  // NOTIFIKASI ADZAN (JADWAL HARIAN)
  // ===================================================================
  /// Menjadwalkan adzan untuk 5 waktu sholat.
  ///
  /// Waktu sholat di jadwalkan berulang tiap hari (`DateTimeComponents.time`),
  /// jadi walaupun aplikasi tidak pernah dibuka lagi, adzan tetap berbunyi.
  Future<void> schedulePrayerNotifications(PrayerTimes prayerTimes) async {
    if (!isSupported) return;
    await init();

    final prefs = await SharedPreferences.getInstance();
    final enableAzan = prefs.getBool('enable_azan') ?? true;

    if (!enableAzan) {
      await cancelAllNotifications();
      return;
    }

    // Bersihkan jadwal lama supaya tidak dobel.
    await _notifications.cancelAll();

    final now = DateTime.now();
    final schedules = <String, DateTime>{
      'Subuh': prayerTimes.fajr,
      'Dzuhur': prayerTimes.dhuhr,
      'Ashar': prayerTimes.asr,
      'Maghrib': prayerTimes.maghrib,
      'Isya': prayerTimes.isha,
    };

    // Simpan supaya bisa dijadwalkan ulang tanpa hitung lokasi lagi
    // (misalnya saat user menyalakan kembali toggle adzan di Pengaturan).
    try {
      await prefs.setString(
        _prayerTimesKey,
        jsonEncode(schedules.map((k, v) => MapEntry(k, v.toIso8601String()))),
      );
    } catch (e) {
      debugPrint('Gagal menyimpan jadwal sholat: $e');
    }

    for (final entry in schedules.entries) {
      await _schedulePrayer(entry.key, entry.value, now);
    }
  }

  /// Menjadwalkan ulang adzan dari jadwal sholat terakhir yang tersimpan.
  /// Dipakai halaman Pengaturan saat user mengaktifkan lagi adzan.
  Future<void> rescheduleFromSavedPrayerTimes() async {
    if (!isSupported) return;
    await init();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prayerTimesKey);
    if (raw == null) return;

    try {
      final Map<String, dynamic> decoded =
          jsonDecode(raw) as Map<String, dynamic>;
      final now = DateTime.now();

      for (final entry in decoded.entries) {
        final parsed = DateTime.tryParse(entry.value.toString());
        if (parsed == null) continue;
        await _schedulePrayer(entry.key, parsed, now);
      }
    } catch (e) {
      debugPrint('Gagal menjadwalkan ulang adzan: $e');
    }
  }

  Future<void> _schedulePrayer(
    String prayerName,
    DateTime prayerTime,
    DateTime now,
  ) async {
    // Geser ke waktu terdekat di masa depan. Karena notifikasi memakai
    // pola berulang harian (`DateTimeComponents.time`), yang penting hanya
    // jam-nya, bukan tanggalnya.
    var target = prayerTime;
    while (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }

    final scheduledDate = tz.TZDateTime.from(target, tz.local);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        azanChannelId,
        _azanChannelName,
        channelDescription: _azanChannelDesc,
        importance: Importance.max,
        priority: Priority.max,
        sound: const RawResourceAndroidNotificationSound(_azanRawSound),
        playSound: true,
        enableVibration: true,
        // Supaya sistem Android memperlakukan ini seperti ALARM,
        // sehingga suaranya tidak dipotong dan tetap keras.
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        visibility: NotificationVisibility.public,
        ticker: 'Waktu sholat $prayerName telah tiba',
        styleInformation: BigTextStyleInformation(
          'Sudah masuk waktu sholat $prayerName. Mari tunaikan sholat berjamaah.',
        ),
        autoCancel: true,
        ongoing: false,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentSound: true,
        sound: _azanIosSound,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    // Urutan mode dari paling tepat waktu sampai paling kompromi.
    // `alarmClock` = setAlarmClock, paling anti-delay & menembus Doze.
    const modes = <AndroidScheduleMode>[
      AndroidScheduleMode.alarmClock,
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ];

    Object? lastError;
    for (final mode in modes) {
      try {
        await _notifications.zonedSchedule(
          _prayerNotificationIds[prayerName] ?? prayerName.hashCode,
          'Waktu Sholat $prayerName',
          'Sudah masuk waktu sholat $prayerName',
          scheduledDate,
          details,
          androidScheduleMode: mode,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'prayer:$prayerName',
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        debugPrint(
          '[Adzan] $prayerName dijadwalkan ($mode) pada $scheduledDate',
        );
        return;
      } catch (e) {
        lastError = e;
        debugPrint('[Adzan] Gagal jadwalkan $prayerName dengan $mode: $e');
      }
    }

    debugPrint(
      '[Adzan] $prayerName GAGAL dijadwalkan. Error terakhir: $lastError',
    );
  }

  /// Menampilkan notifikasi adzan SEKARANG (dipakai tombol "Tes Adzan").
  Future<bool> showTestAzan() async {
    if (!isSupported) return false;
    await init();
    try {
      await _notifications.show(
        _testAzanNotificationId,
        'Tes Suara Adzan',
        'Kalau kamu mendengar suara adzan, berarti pengaturan adzan sudah benar.',
        NotificationDetails(
          android: AndroidNotificationDetails(
            azanChannelId,
            _azanChannelName,
            channelDescription: _azanChannelDesc,
            importance: Importance.max,
            priority: Priority.max,
            sound: const RawResourceAndroidNotificationSound(_azanRawSound),
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.alarm,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            visibility: NotificationVisibility.public,
            ticker: 'Tes suara adzan',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentSound: true,
            sound: _azanIosSound,
          ),
        ),
        payload: 'adzan:test',
      );
      return true;
    } catch (e) {
      debugPrint('Gagal menampilkan notifikasi tes adzan: $e');
      return false;
    }
  }

  // ===================================================================
  // NOTIFIKASI DZIKIR SELESAI
  // ===================================================================
  /// Menampilkan notifikasi "Alhamdulillah, kamu sudah menyelesaikan dzikir
  /// pagi / sore".
  Future<void> showDzikirCompleted({required bool isPagi}) async {
    if (!isSupported) return;
    await init();

    final waktu = isPagi ? 'pagi' : 'sore';

    try {
      await _notifications.show(
        isPagi ? _dzikirPagiNotificationId : _dzikirSoreNotificationId,
        'Alhamdulillah, kamu sudah menyelesaikan dzikir $waktu',
        'Semoga Allah menerima dzikir dan doa-doamu hari ini. 🤲',
        NotificationDetails(
          android: AndroidNotificationDetails(
            dzikirChannelId,
            _dzikirChannelName,
            channelDescription: _dzikirChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.status,
            styleInformation: BigTextStyleInformation(
              'Alhamdulillah, kamu sudah menyelesaikan seluruh rangkaian '
              'dzikir $waktu. Semoga menjadi amal yang diterima dan '
              'menenangkan hati. 🤲',
            ),
            ticker: 'Dzikir $waktu selesai',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentSound: true,
          ),
        ),
        payload: 'dzikir:$waktu',
      );
    } catch (e) {
      debugPrint('Gagal menampilkan notifikasi dzikir: $e');
    }
  }

  // ===================================================================
  // UTIL
  // ===================================================================
  Future<void> cancelAllNotifications() async {
    if (!isSupported) return;
    await _notifications.cancelAll();
  }

  /// Info buat debugging: daftar notifikasi yang masih menunggu di sistem.
  Future<List<PendingNotificationRequest>> pendingNotifications() async {
    if (!isSupported) return const [];
    return _notifications.pendingNotificationRequests();
  }

  /// Cek apakah jadwal sholat sudah pernah dihitung (dipakai untuk memberi
  /// tahu user kalau adzan belum bisa dijadwalkan karena GPS belum aktif).
  Future<bool> hasSavedPrayerTimes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prayerTimesKey) != null;
  }
}
