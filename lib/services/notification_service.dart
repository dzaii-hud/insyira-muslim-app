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

  /// Channel khusus PENGINGAT dzikir pagi & sore.
  ///
  /// Sengaja dipisah dari [dzikirChannelId] — yang dipakai untuk kabar
  /// "kamu baru selesai berdzikir" — supaya pengingat harian bisa dimatikan
  /// user tanpa ikut mematikan notifikasi penyelesaian dzikir (dan sebaliknya).
  static const String dzikirReminderChannelId = 'dzikir_reminder_channel_v1';

  /// Channel untuk kabar "kajian sedang live".
  ///
  /// Dipisah dari channel adzan supaya user bisa membisukan kabar kajian
  /// tanpa ikut mematikan adzan (dan sebaliknya).
  static const String kajianChannelId = 'kajian_live_channel_v1';

  /// Nama file native tanpa ekstensi di `android/app/src/main/res/raw/`.
  static const String _azanRawSound = 'adzan';

  /// Nama file suara untuk iOS (harus ditambahkan ke bundle Xcode).
  static const String _azanIosSound = 'adzan.mp3';

  static const String _azanChannelName = 'Suara Adzan';
  static const String _azanChannelDesc = 'Adzan saat masuk waktu sholat';
  static const String _dzikirChannelName = 'Dzikir Harian';
  static const String _dzikirChannelDesc =
      'Notifikasi setelah kamu menyelesaikan dzikir';
  static const String _dzikirReminderChannelName = 'Pengingat Dzikir';
  static const String _dzikirReminderChannelDesc =
      'Pengingat dzikir pagi (09:00) dan sore (17:00)';

  static const String _kajianChannelName = 'Kajian Live';
  static const String _kajianChannelDesc =
      'Kabar ketika Insyira TV sedang menyiarkan kajian secara live';

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

  /// ID notifikasi PENGINGAT dzikir pagi & sore.
  static const int _dzikirPagiReminderId = 2103;
  static const int _dzikirSoreReminderId = 2104;

  /// Jam pengingat dzikir (waktu lokal perangkat).
  static const int jamDzikirPagi = 9;
  static const int jamDzikirSore = 17;

  /// Toggle di halaman Pengaturan: pengingat dzikir pagi & sore.
  static const String _pengingatDzikirKey = 'enable_dzikir_reminder';

  /// ID notifikasi kabar kajian live. Sengaja ID tetap (bukan hashCode)
  /// supaya kabar baru menimpa kabar lama, tidak menumpuk di laci notifikasi.
  static const int _kajianLiveNotificationId = 2201;

  /// Menyimpan ID video live terakhir yang sudah diberitahukan, supaya satu
  /// siaran tidak mengirim notifikasi berulang kali.
  static const String _liveVideoKey = 'notified_live_video_id';

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

    // Channel pengingat dzikir: dipisah supaya bisa dibisukan sendiri.
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        dzikirReminderChannelId,
        _dzikirReminderChannelName,
        description: _dzikirReminderChannelDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    // Channel kajian live: pentingnya HIGH (perlu muncul sebagai banner),
    // tapi tanpa suara adzan — cukup getaran + suara notifikasi bawaan.
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        kajianChannelId,
        _kajianChannelName,
        description: _kajianChannelDesc,
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

    var enabled = await android.areNotificationsEnabled() ?? true;
    if (!enabled) {
      // Minta izin, lalu BACA ULANG statusnya.
      //
      // Versi lama mengembalikan status SEBELUM diminta, sehingga selalu
      // melaporkan "izin tertutup" walaupun user baru saja menyetujuinya.
      await android.requestNotificationsPermission();
      enabled = await android.areNotificationsEnabled() ?? false;
    }
    try {
      await android.requestExactAlarmsPermission();
    } catch (_) {}
    return enabled;
  }

  // ===================================================================
  // NOTIFIKASI ADZAN (JADWAL HARIAN)
  // ===================================================================
  /// Mengubah [PrayerTimes] menjadi peta `nama waktu -> waktu`, dengan urutan
  /// waktu sholat (bukan urutan abjad).
  static Map<String, DateTime> petaWaktuSholat(PrayerTimes t) =>
      <String, DateTime>{
        'Subuh': t.fajr,
        'Dzuhur': t.dhuhr,
        'Ashar': t.asr,
        'Maghrib': t.maghrib,
        'Isya': t.isha,
      };

  /// Waktu lokal berikutnya pada jam [jam]:[menit] — hari ini kalau belum
  /// lewat, atau besok kalau sudah lewat.
  static DateTime waktuLokalBerikutnya(int jam, int menit) {
    final sekarang = DateTime.now();
    final hariIni = DateTime(
      sekarang.year,
      sekarang.month,
      sekarang.day,
      jam,
      menit,
    );
    return hariIni.isAfter(sekarang)
        ? hariIni
        : hariIni.add(const Duration(days: 1));
  }

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
      await cancelAdzanNotifications();
      return;
    }

    // Bersihkan jadwal adzan lama supaya tidak dobel.
    //
    // ⚠️ JANGAN memakai `cancelAll()` di sini. Fungsi ini dipanggil setiap
    // kali aplikasi dibuka, dan `cancelAll()` ikut menghapus pengingat
    // dzikir pagi/sore yang sudah terjadwal (bug yang pernah terjadi).
    await cancelAdzanNotifications();

    final now = DateTime.now();
    final schedules = petaWaktuSholat(prayerTimes);

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

    await _jadwalkanDenganCadangan(
      id: _prayerNotificationIds[prayerName] ?? prayerName.hashCode,
      judul: 'Waktu Sholat $prayerName',
      isi: 'Sudah masuk waktu sholat $prayerName',
      target: tz.TZDateTime.from(target, tz.local),
      details: _azanDetails(prayerName),
      payload: 'prayer:$prayerName',
      label: 'Adzan $prayerName',
    );
  }

  /// Detail notifikasi adzan untuk satu waktu sholat.
  ///
  /// Dipisah supaya jalur TERJADWAL ([_schedulePrayer]) dan jalur
  /// "aplikasi sedang dibuka" ([showAdzanNow]) memakai tampilan & suara yang
  /// persis sama — kalau tidak, adzan bisa terdengar berbeda tergantung
  /// aplikasi sedang dibuka atau tidak.
  NotificationDetails _azanDetails(String prayerName) {
    return NotificationDetails(
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
  }

  /// Menjadwalkan satu notifikasi berulang harian.
  ///
  /// Urutan mode dari paling tepat waktu sampai paling kompromi.
  /// `alarmClock` = setAlarmClock, paling anti-delay & menembus Doze.
  /// Cadangan diperlukan karena izin "Alarm & pengingat"
  /// (`SCHEDULE_EXACT_ALARM`) bisa saja belum diberikan user — kalau semua
  /// mode gagal, itu dicatat di log supaya bisa dilihat lewat `flutter logs`.
  Future<void> _jadwalkanDenganCadangan({
    required int id,
    required String judul,
    required String isi,
    required tz.TZDateTime target,
    required NotificationDetails details,
    required String label,
    String? payload,
  }) async {
    const modes = <AndroidScheduleMode>[
      AndroidScheduleMode.alarmClock,
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ];

    Object? lastError;
    for (final mode in modes) {
      try {
        await _notifications.zonedSchedule(
          id,
          judul,
          isi,
          target,
          details,
          androidScheduleMode: mode,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        debugPrint('[Notif] $label dijadwalkan ($mode) pada $target');
        return;
      } catch (e) {
        lastError = e;
        debugPrint('[Notif] Gagal jadwalkan $label dengan $mode: $e');
      }
    }

    debugPrint('[Notif] $label GAGAL dijadwalkan. Error terakhir: $lastError');
  }

  /// Pesan kesalahan terakhir saat menampilkan notifikasi tes adzan.
  ///
  /// Dipakai halaman Pengaturan supaya penyebab aslinya bisa ikut dilaporkan
  /// tester, bukan cuma "gagal" tanpa keterangan (dilaporkan 22 Sep 2026).
  String? lastTestAzanError;

  /// Menampilkan notifikasi adzan SEKARANG (dipakai tombol "Tes Adzan").
  Future<bool> showTestAzan() async {
    if (!isSupported) return false;
    lastTestAzanError = null;
    try {
      // init() ikut di dalam try. Sebelumnya di luar, jadi kalau pembuatan
      // channel gagal (mis. berkas suara bermasalah) exception-nya lolos
      // tanpa terekam.
      await init();
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
      lastTestAzanError = e.toString();
      debugPrint('Gagal menampilkan notifikasi tes adzan: $e');
      return false;
    }
  }

  // ===================================================================
  // ADZAN SAAT APLIKASI SEDANG DIBUKA
  // ===================================================================
  /// Menampilkan notifikasi adzan SEGERA (tanpa menunggu alarm sistem).
  ///
  /// Dipakai Home saat aplikasi sedang dibuka dan waktu sholat baru saja
  /// masuk. Ini jalur yang membuat adzan tetap berbunyi walaupun alarm
  /// sistem diblokir oleh penghemat baterai (kebiasaan HP Xiaomi/Oppo/Vivo).
  ///
  /// ID notifikasi yang dipakai SAMA dengan jalur terjadwal, jadi keduanya
  /// tidak menghasilkan dua baris notifikasi.
  Future<bool> showAdzanNow(String namaWaktu) async {
    if (!isSupported) return false;
    try {
      await init();
      await _notifications.show(
        _prayerNotificationIds[namaWaktu] ?? namaWaktu.hashCode,
        'Waktu Sholat $namaWaktu',
        'Sudah masuk waktu sholat $namaWaktu',
        _azanDetails(namaWaktu),
        payload: 'prayer:$namaWaktu',
      );
      debugPrint('[Adzan] $namaWaktu ditampilkan langsung (aplikasi dibuka)');
      return true;
    } catch (e) {
      debugPrint('[Adzan] Gagal menampilkan adzan $namaWaktu: $e');
      return false;
    }
  }

  /// Membatalkan alarm adzan [namaWaktu] yang belum berbunyi.
  ///
  /// Dipakai tak lama SEBELUM waktu sholat masuk saat aplikasi sedang dibuka.
  /// Tujuannya supaya alarm sistem tidak berbunyi bersamaan dengan
  /// [showAdzanNow] (adzan dua kali di saat yang sama). Rantai jadwal harian
  /// dipulihkan lagi oleh [jadwalkanUlangAdzan] tepat setelahnya.
  Future<void> batalkanAdzanTertunda(String namaWaktu) async {
    if (!isSupported) return;
    final id = _prayerNotificationIds[namaWaktu];
    if (id == null) return;
    await _notifications.cancel(id);
  }

  /// Menjadwalkan ULANG satu waktu sholat untuk hari berikutnya.
  ///
  /// Wajib dipanggil setelah [batalkanAdzanTertunda], kalau tidak jadwal
  /// hariannya putus dan adzan besok tidak berbunyi.
  Future<void> jadwalkanUlangAdzan(String namaWaktu) async {
    if (!isSupported) return;
    final jadwal = await getSavedPrayerTimes();
    final waktu = jadwal[namaWaktu];
    if (waktu == null) return;
    await _schedulePrayer(namaWaktu, waktu, DateTime.now());
  }

  /// Apakah adzan [namaWaktu] hari ini sudah pernah berbunyi.
  ///
  /// Dipakai supaya jalur "aplikasi sedang dibuka" tidak berbunyi berkali-kali
  /// untuk waktu sholat yang sama.
  Future<bool> sudahDiadzankanHariIni(String namaWaktu) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kunciPenandaAdzan(namaWaktu)) == _tanggalHariIni();
  }

  /// Mencatat bahwa adzan [namaWaktu] hari ini sudah berbunyi.
  Future<void> tandaiSudahDiadzankan(String namaWaktu) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kunciPenandaAdzan(namaWaktu), _tanggalHariIni());
  }

  static String _kunciPenandaAdzan(String namaWaktu) =>
      'adzan_notified_$namaWaktu';

  static String _tanggalHariIni() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  // ===================================================================
  // PENGINGAT DZIKIR PAGI & SORE
  // ===================================================================
  /// Menjadwalkan ulang pengingat dzikir pagi (09:00) dan sore (17:00).
  ///
  /// Aman dipanggil berkali-kali: ID notifikasinya tetap, jadi jadwal lama
  /// ditimpa jadwal baru (tidak menumpuk di laci notifikasi).
  Future<void> scheduleDzikirReminders() async {
    if (!isSupported) return;
    await init();

    final prefs = await SharedPreferences.getInstance();
    final aktif = prefs.getBool(_pengingatDzikirKey) ?? true;

    // Selalu bersihkan dulu supaya jadwal lama tidak tertinggal.
    await _notifications.cancel(_dzikirPagiReminderId);
    await _notifications.cancel(_dzikirSoreReminderId);

    if (!aktif) {
      debugPrint('[Dzikir] Pengingat dzikir dimatikan user');
      return;
    }

    await _jadwalkanPengingatDzikir(
      id: _dzikirPagiReminderId,
      jam: jamDzikirPagi,
      waktu: 'pagi',
    );
    await _jadwalkanPengingatDzikir(
      id: _dzikirSoreReminderId,
      jam: jamDzikirSore,
      waktu: 'sore',
    );
  }

  Future<void> _jadwalkanPengingatDzikir({
    required int id,
    required int jam,
    required String waktu,
  }) async {
    final target = tz.TZDateTime.from(waktuLokalBerikutnya(jam, 0), tz.local);

    await _jadwalkanDenganCadangan(
      id: id,
      judul: 'Pengingat Dzikir ${waktu[0].toUpperCase()}${waktu.substring(1)}',
      isi: 'Sudahkah Anda berdzikir $waktu hari ini?',
      target: target,
      details: NotificationDetails(
        android: AndroidNotificationDetails(
          dzikirReminderChannelId,
          _dzikirReminderChannelName,
          channelDescription: _dzikirReminderChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.reminder,
          ticker: 'Pengingat dzikir $waktu',
          styleInformation: BigTextStyleInformation(
            'Sudahkah Anda berdzikir $waktu hari ini?\n\n'
            'Luangkan beberapa menit untuk membaca dzikir $waktu — '
            'insyaAllah hati jadi lebih tenang.',
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
      payload: 'dzikir_reminder:$waktu',
      label: 'Pengingat dzikir $waktu',
    );
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
  // KABAR KAJIAN LIVE
  // ===================================================================
  /// Menampilkan notifikasi "kajian sedang live" beserta judul siarannya.
  ///
  /// Dipanggil dari Home setiap kali aplikasi memeriksa endpoint
  /// `/youtube/live` dan menemukan siaran yang BELUM pernah diberitahukan.
  /// [videoId] ikut dikirim sebagai payload supaya saat notifikasinya ditekan
  /// aplikasi bisa langsung membuka siarannya di YouTube.
  Future<void> showKajianLiveNotification({
    required String judul,
    required String videoId,
  }) async {
    if (!isSupported) return;
    await init();

    final String judulBersih = judul.trim().isEmpty
        ? 'Insyira TV sedang live'
        : judul.trim();

    try {
      await _notifications.show(
        _kajianLiveNotificationId,
        '🔴 Kajian sedang LIVE sekarang',
        judulBersih,
        NotificationDetails(
          android: AndroidNotificationDetails(
            kajianChannelId,
            _kajianChannelName,
            channelDescription: _kajianChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.social,
            ticker: 'Kajian live dimulai',
            styleInformation: BigTextStyleInformation(
              '$judulBersih\n\nKetuk untuk menonton di YouTube.',
            ),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentSound: true,
          ),
        ),
        payload: 'kajian_live:$videoId',
      );
    } catch (e) {
      debugPrint('Gagal menampilkan notifikasi kajian live: $e');
    }
  }

  /// ID video live terakhir yang sudah diberitahukan ke user.
  ///
  /// Dipakai supaya satu siaran hanya menghasilkan SATU notifikasi, walau
  /// aplikasi memeriksa status live berkali-kali.
  Future<String?> lastNotifiedLiveVideoId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_liveVideoKey);
  }

  Future<void> setLastNotifiedLiveVideoId(String videoId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_liveVideoKey, videoId);
  }

  /// Menghapus penanda "sudah diberitahukan" supaya siaran berikutnya
  /// (ID berbeda) tetap memicu notifikasi baru. Berguna untuk pengujian.
  Future<void> clearLastNotifiedLiveVideo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_liveVideoKey);
  }

  // ===================================================================
  // DATA UNTUK PANEL NOTIFIKASI
  // ===================================================================
  /// Jadwal sholat terakhir yang dipakai untuk menjadwalkan adzan.
  ///
  /// Dikembalikan sebagai peta `namaWaktu -> waktu`, contoh:
  /// `{'Subuh': 2026-09-22 04:48, 'Dzuhur': ...}`.
  ///
  /// Panel notifikasi (ikon lonceng) memakai ini untuk menampilkan semua
  /// notifikasi adzan hari ini beserta statusnya. Urutannya sengaja mengikuti
  /// urutan waktu sholat, bukan urutan abjad.
  Future<Map<String, DateTime>> getSavedPrayerTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prayerTimesKey);
    if (raw == null) return <String, DateTime>{};

    try {
      final Map<String, dynamic> decoded =
          jsonDecode(raw) as Map<String, dynamic>;

      final hasil = <String, DateTime>{};
      for (final nama in _prayerNotificationIds.keys) {
        final nilai = decoded[nama];
        final waktu = DateTime.tryParse(nilai?.toString() ?? '');
        if (waktu != null) hasil[nama] = waktu;
      }
      return hasil;
    } catch (e) {
      debugPrint('Gagal membaca jadwal sholat tersimpan: $e');
      return <String, DateTime>{};
    }
  }

  /// Apakah adzan otomatis sedang aktif (toggle di halaman Pengaturan).
  Future<bool> isAzanEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('enable_azan') ?? true;
  }

  // ===================================================================
  // UTIL
  // ===================================================================
  Future<void> cancelAllNotifications() async {
    if (!isSupported) return;
    await _notifications.cancelAll();
  }

  /// Membatalkan HANYA notifikasi adzan (5 waktu sholat).
  ///
  /// ⚠️ Jangan kembali memakai `cancelAll()` di jalur penjadwalan adzan:
  /// fungsi itu ikut menghapus pengingat dzikir dan notifikasi terjadwal lain.
  Future<void> cancelAdzanNotifications() async {
    if (!isSupported) return;
    for (final id in _prayerNotificationIds.values) {
      await _notifications.cancel(id);
    }
  }

  /// Meminta izin \"Alarm & pengingat\" (`SCHEDULE_EXACT_ALARM`).
  ///
  /// Tanpa izin ini adzan tetap dijadwalkan, tetapi memakai mode inexact
  /// sehingga waktunya bisa tertunda beberapa menit — dan di HP dengan
  /// penghemat baterai agresif bisa tidak berbunyi sama sekali.
  Future<void> mintaIzinAlarmPresisi() async {
    if (!isSupported) return;
    try {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('Gagal meminta izin alarm presisi: $e');
    }
  }

  /// Ringkasan kesiapan notifikasi untuk halaman Pengaturan.
  ///
  /// Dibuat supaya masalah "adzan tidak pernah berbunyi" bisa dilihat
  /// penyebabnya dari dalam aplikasi: izin notifikasi, izin alarm presisi,
  /// dan berapa alarm yang benar-benar terdaftar di sistem.
  Future<NotificationStatus> getStatus() async {
    if (!isSupported) {
      return const NotificationStatus(
        didukung: false,
        izinNotifikasi: false,
        izinAlarmPresisi: false,
        jumlahAdzanTerjadwal: 0,
        adzanBerikutnya: null,
        pengingatDzikirAktif: false,
      );
    }

    await init();

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    bool izinNotifikasi = true;
    bool izinAlarmPresisi = true;
    try {
      izinNotifikasi = await android?.areNotificationsEnabled() ?? true;
      izinAlarmPresisi = await android?.canScheduleExactNotifications() ?? true;
    } catch (e) {
      debugPrint('Gagal membaca status izin notifikasi: $e');
    }

    List<PendingNotificationRequest> tertunda;
    try {
      tertunda = await _notifications.pendingNotificationRequests();
    } catch (e) {
      debugPrint('Gagal membaca daftar notifikasi tertunda: $e');
      tertunda = const <PendingNotificationRequest>[];
    }

    final idAdzan = _prayerNotificationIds.values.toSet();
    final adzanTerjadwal = tertunda.where((n) => idAdzan.contains(n.id)).length;

    final prefs = await SharedPreferences.getInstance();
    final jadwal = await getSavedPrayerTimes();
    final sekarang = DateTime.now();
    DateTime? berikutnya;
    for (final waktu in jadwal.values) {
      final kandidat = waktu.isAfter(sekarang)
          ? waktu
          : waktu.add(const Duration(days: 1));
      if (berikutnya == null || kandidat.isBefore(berikutnya)) {
        berikutnya = kandidat;
      }
    }

    return NotificationStatus(
      didukung: true,
      izinNotifikasi: izinNotifikasi,
      izinAlarmPresisi: izinAlarmPresisi,
      jumlahAdzanTerjadwal: adzanTerjadwal,
      adzanBerikutnya: berikutnya,
      pengingatDzikirAktif: prefs.getBool(_pengingatDzikirKey) ?? true,
      jumlahNotifikasiTertunda: tertunda.length,
    );
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

/// Ringkasan kesiapan notifikasi — lihat [NotificationService.getStatus].
class NotificationStatus {
  const NotificationStatus({
    required this.didukung,
    required this.izinNotifikasi,
    required this.izinAlarmPresisi,
    required this.jumlahAdzanTerjadwal,
    required this.adzanBerikutnya,
    required this.pengingatDzikirAktif,
    this.jumlahNotifikasiTertunda = 0,
  });

  /// Notifikasi lokal memang tersedia di perangkat ini (bukan web).
  final bool didukung;

  /// Izin menampilkan notifikasi (Android 13+ / POST_NOTIFICATIONS).
  final bool izinNotifikasi;

  /// Izin \"Alarm & pengingat\". Tanpa izin ini adzan tetap dijadwalkan, tetapi
  /// memakai mode inexact sehingga waktunya bisa tertunda beberapa menit.
  final bool izinAlarmPresisi;

  /// Berapa waktu sholat yang alarmnya benar-benar terdaftar di sistem.
  final int jumlahAdzanTerjadwal;

  /// Perkiraan waktu sholat berikutnya menurut jadwal yang tersimpan.
  final DateTime? adzanBerikutnya;

  final bool pengingatDzikirAktif;

  /// Total notifikasi yang masih menunggu di sistem (adzan + pengingat).
  final int jumlahNotifikasiTertunda;

  /// Adzan sudah terpasang dan izinnya lengkap.
  bool get siap => didukung && izinNotifikasi && jumlahAdzanTerjadwal > 0;
}
