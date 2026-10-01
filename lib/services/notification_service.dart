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

  /// Channel untuk PENGINGAT jadwal kajian (H-30 menit & saat jam mulai).
  ///
  /// Dipisah dari [kajianChannelId] — yang dipakai untuk kabar "sedang live" —
  /// karena keduanya berbeda sifat: kabar live datangnya mendadak dan hanya
  /// berlaku saat ada siaran, sedangkan pengingat jadwal terikat pada jadwal
  /// yang sudah diisi admin. User harus bisa mematikan salah satunya saja.
  static const String kajianReminderChannelId = 'kajian_reminder_channel_v1';

  /// Channel untuk PENGINGAT PENYELAMAT RUNTUTAN (dzikir & baca Al-Qur'an).
  /// Dipisah supaya bisa dibisukan sendiri tanpa ikut mematikan adzan.
  static const String streakChannelId = 'streak_channel_v1';

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
  static const String _kajianReminderChannelName = 'Pengingat Jadwal Kajian';
  static const String _kajianReminderChannelDesc =
      'Pengingat 30 menit sebelum kajian dimulai dan saat kajian dimulai';
  static const String _streakChannelName = 'Runtutan Harian';
  static const String _streakChannelDesc =
      'Pengingat menjelang malam kalau dzikir & baca Al-Qur\'an hari ini belum tuntas';

  /// Urutan waktu sholat.
  ///
  /// Selain dipakai untuk urutan tampilan, URUTAN INI menentukan blok ID
  /// notifikasi adzan (lihat [_adzanIdDasar]). Jangan diubah tanpa
  /// menyesuaikannya.
  static const List<String> urutanWaktuSholat = <String>[
    'Subuh',
    'Dzuhur',
    'Ashar',
    'Maghrib',
    'Isya',
  ];

  /// Berapa hari ke depan jadwal adzan dipasang sekaligus.
  ///
  /// Kenapa TIDAK memakai satu alarm berulang tiap hari seperti dulu:
  /// alarm berulang berpegang pada JAM TETAP, sedangkan waktu sholat bergeser
  /// sedikit tiap hari. Untuk Pekanbaru, penyimpangannya mencapai −10 sampai
  /// **+40 menit** dalam setahun (Ashar paling parah) — artinya adzan bisa
  /// berbunyi 40 menit SEBELUM masuk waktu. Dengan memasang jam yang tepat
  /// untuk tiap hari, penyimpangan itu hilang sama sekali.
  static const int hariAdzanKeDepan = 30;

  /// Jadwal diisi ulang kalau sisa cakupannya tinggal segini (hari).
  ///
  /// Sengaja TIDAK diisi ulang tiap aplikasi dibuka: karena tiap hari sudah
  /// memakai jamnya sendiri, memasang ulang 150 alarm terus-menerus hanya
  /// membuang waktu dan baterai.
  static const int _sisaHariIsiUlang = 15;

  /// Blok ID notifikasi adzan: 1100 = Subuh, 1200 = Dzuhur, 1300 = Ashar,
  /// 1400 = Maghrib, 1500 = Isya. Tiap blok selebar 100 ID — satu ID per hari.
  static const int _adzanIdDasar = 1100;
  static const int _adzanIdBlok = 100;

  /// ID notifikasi adzan yang ditampilkan LANGSUNG saat aplikasi sedang dibuka
  /// (jalur cadangan kalau alarm sistem diblokir penghemat baterai).
  /// Sengaja di luar rentang terjadwal supaya tidak saling menimpa.
  static const int _adzanIdLangsungDasar = 1600;

  /// ID notifikasi adzan versi LAMA (satu alarm berulang tiap hari).
  /// Hanya dipakai untuk membersihkan sisa alarm di HP yang sudah memasang
  /// versi sebelumnya — kalau tidak dibatalkan, adzan akan berbunyi dua kali.
  static const List<int> _adzanIdLama = <int>[1101, 1102, 1103, 1104, 1105];

  /// Prefs: tanggal terakhir yang sudah tercakup jadwal adzan (`yyyy-MM-dd`).
  static const String _adzanSampaiKey = 'adzan_terjadwal_sampai';

  /// Prefs: koordinat yang dipakai saat jadwal dipasang, `lat,lon` dibulatkan
  /// 2 desimal (≈1 km). Dipakai untuk (a) memasang ulang tanpa GPS saat user
  /// menyalakan lagi toggle adzan, dan (b) mendeteksi user pindah area.
  static const String _adzanKoordinatKey = 'adzan_koordinat';

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

  // --- Pengingat jadwal kajian -------------------------------------------
  /// Berapa hari ke depan pengingat kajian dipasang.
  ///
  /// Sama seperti adzan, tiap pengingat dipasang pada TANGGAL & JAM persis
  /// (bukan jam tetap yang diulang), karena jadwal kajian berbeda-beda.
  static const int hariKajianKeDepan = 30;

  /// Berapa menit sebelum kajian dimulai pengingat pertama berbunyi.
  static const int menitPengingatKajian = 30;

  /// Blok ID pengingat kajian: 2300 + (hari ke-N × 20) + (kajian ke-N × 2).
  ///
  /// Tiap kajian memakai DUA ID berurutan: yang pertama untuk pengingat
  /// H-30 menit, yang kedua untuk saat jam mulai. Rentangnya 2300–2899, aman
  /// di antara notifikasi kajian live (2201) dan tombol Tes Adzan (2999).
  static const int _kajianIdDasar = 2300;
  static const int _kajianIdPerHari = 20;

  /// Batas jumlah kajian per hari yang dipasangi pengingat.
  ///
  /// Dibatasi supaya ID-nya tidak melimpah keluar blok 2300–2899 kalau suatu
  /// hari jadwalnya luar biasa padat. 10 kajian per hari sudah jauh di atas
  /// kebutuhan nyata; sisa jadwal pagi tetap tampil di aplikasi, hanya
  /// pengingatnya yang tidak dipasang.
  static const int _kajianMaksPerHari = 10;

  /// Toggle di halaman Pengaturan: pengingat jadwal kajian.
  static const String _pengingatKajianKey = 'enable_kajian_reminder';

  /// Prefs: daftar ID pengingat kajian yang sedang terpasang (JSON array).
  /// Dipakai untuk membatalkan HANYA yang pernah dipasang — jauh lebih hemat
  /// daripada mencoba membatalkan 600 ID setiap kali jadwal diperbarui.
  static const String _kajianTerjadwalKey = 'kajian_terjadwal_ids';

  /// Prefs: daftar kajian terakhir yang dipakai memasang pengingat.
  /// Dipakai halaman Pengaturan untuk memasang ulang TANPA mengambil data
  /// dari API lagi saat user menyalakan kembali toggle-nya.
  static const String _kajianDaftarKey = 'kajian_terjadwal_daftar';

  // --- Pengingat penyelamat runtutan --------------------------------------
  /// Jam pengingat runtutan (waktu lokal perangkat).
  ///
  /// ⚠️ Pukul 16:00, BUKAN 20:00 seperti sebelumnya. Alasannya: sejak
  /// 1 Okt 2026 dzikir punya batas waktu (pagi sampai 11:00, petang sampai
  /// 18:00). Pengingat pukul 20:00 jadi mustahil menolong — saat itu semua
  /// dzikir sudah ditutup, jadi yang bisa diselamatkan tinggal baca Al-Qur'an.
  /// Pukul 16:00 masih menyisakan dua jam untuk dzikir petang, sehingga
  /// pengingat ini benar-benar bisa menyelamatkan runtutan.
  static const int jamPengingatStreak = 16;

  /// Berapa hari ke depan pengingat runtutan dipasang.
  ///
  /// Lebih pendek dari adzan/kajian karena pengingatnya diperbarui hampir
  /// setiap kali aplikasi dibuka (progres berubah → jadwalnya ditata ulang).
  static const int hariPengingatStreakKeDepan = 7;

  /// ID pengingat runtutan: [2900] untuk hari ini, 2901 besok, dan seterusnya.
  ///
  /// 2900–2906 sengaja dipilih karena masih kosong: adzan memakai 1100–1604,
  /// dzikir 2101–2104, kajian live 2201, pengingat kajian 2300–2899, dan
  /// tombol Tes Adzan 2999.
  static const int _streakIdDasar = 2900;

  /// Prefs: daftar ID pengingat runtutan yang sedang terpasang.
  static const String _streakTerjadwalKey = 'streak_terjadwal_ids';

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

  /// Payload notifikasi yang MEMBUKA aplikasi dari kondisi tertutup.
  ///
  /// [onNotificationTap] hanya terpicu kalau aplikasi sudah hidup, jadi kasus
  /// "aplikasi tertutup lalu dibuka dari notifikasi" tidak terpegang lewat
  /// callback itu. Payload-nya dibaca sekali saat [init] dan disimpan di sini
  /// supaya bisa diambil setelah aplikasi benar-benar siap.
  String? _payloadPembuka;

  /// Mengambil payload pembuka. Sekali ambil langsung dihapus, supaya
  /// halaman yang dibuka berulang kali tidak terlempar ke sana lagi.
  String? ambilPayloadPembuka() {
    final String? payload = _payloadPembuka;
    _payloadPembuka = null;
    return payload;
  }

  // ===================================================================
  // INISIALISASI
  // ===================================================================
  /// Proses inisialisasi yang sedang berjalan (kalau ada).
  ///
  /// Dipakai supaya `init()` bisa dipanggil dari beberapa tempat SEKALIGUS
  /// tanpa menjalankan `_notifications.initialize()` dua kali. Ini bukan
  /// kehati-hatian yang berlebihan: saat aplikasi dibuka, `main()`, Home,
  /// dan penjadwalan pengingat memanggilnya hampir bersamaan — dan penjagaan
  /// `_initialized` saja tidak cukup, karena nilainya baru di-set di AKHIR
  /// proses yang berjalan asinkron.
  Future<void>? _inisialisasi;

  Future<void> init() {
    if (!isSupported) return Future<void>.value();
    return _inisialisasi ??= _inisialisasiSekali();
  }

  Future<void> _inisialisasiSekali() async {
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

    // Kalau aplikasi dibuka DARI sebuah notifikasi (kondisi tertutup), ketukan
    // itu tidak lewat `onDidReceiveNotificationResponse` — payload-nya harus
    // dibaca di sini, sekali saja. Halaman Home yang akan memprosesnya lewat
    // `NotificationNavigator.tanganiTertunda()`.
    try {
      final NotificationAppLaunchDetails? pembuka = await _notifications
          .getNotificationAppLaunchDetails();
      if (pembuka?.didNotificationLaunchApp ?? false) {
        _payloadPembuka = pembuka?.notificationResponse?.payload;
      }
    } catch (e) {
      debugPrint('[Notif] Gagal membaca notifikasi pembuka: $e');
    }

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

    // Channel pengingat jadwal kajian: dipisah supaya bisa dibisukan sendiri.
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        kajianReminderChannelId,
        _kajianReminderChannelName,
        description: _kajianReminderChannelDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    // Channel pengingat runtutan: dipisah supaya bisa dibisukan sendiri.
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        streakChannelId,
        _streakChannelName,
        description: _streakChannelDesc,
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

  /// Parameter hisab yang dipakai aplikasi: metode Singapore + madzhab Syafi'i.
  ///
  /// Ada di sini supaya halaman utama dan proses penjadwalan ulang (yang tidak
  /// punya akses lokasi) memakai perhitungan yang PERSIS sama.
  static CalculationParameters parameterSholat() {
    final params = CalculationMethod.singapore.getParameters();
    params.madhab = Madhab.shafi;
    return params;
  }

  /// ID notifikasi untuk satu waktu sholat pada satu hari ke depan.
  static int idAdzan(int indexWaktu, int hariKe) =>
      _adzanIdDasar + indexWaktu * _adzanIdBlok + hariKe;

  /// ID notifikasi adzan yang ditampilkan langsung (bukan terjadwal).
  static int idAdzanLangsung(int indexWaktu) =>
      _adzanIdLangsungDasar + indexWaktu;

  /// ID pengingat penyelamat runtutan untuk [hariKe] hari dari sekarang
  /// (0 = hari ini).
  static int idPengingatStreak(int hariKe) => _streakIdDasar + hariKe;

  /// Menyusun daftar alarm adzan untuk [hari] hari ke depan.
  ///
  /// ⚠️ Fungsi ini SENGAJA MURNI — tidak menyentuh plugin notifikasi — supaya
  /// rencananya bisa diuji tanpa HP (lihat `test/notifikasi_adzan_test.dart`).
  /// Yang dijaga tes itu: **tiap hari memakai jam HARI ITU**, bukan jam yang
  /// sama terus. Itulah inti perbaikan ketepatan adzan.
  ///
  /// Waktu sholat hari ini yang sudah lewat tidak ikut dijadwalkan.
  static List<JadwalAdzan> rencanaJadwalAdzan(
    PrayerTimes dasar, {
    int hari = hariAdzanKeDepan,
    DateTime? sekarang,
  }) {
    final saat = sekarang ?? DateTime.now();
    final awalHari = DateTime(saat.year, saat.month, saat.day);
    final rencana = <JadwalAdzan>[];

    for (int h = 0; h < hari; h++) {
      // Jadwal hari ke-h dihitung sendiri, jadi jamnya tepat untuk hari itu.
      final jadwalHari = PrayerTimes(
        dasar.coordinates,
        DateComponents.from(awalHari.add(Duration(days: h))),
        dasar.calculationParameters,
      );
      final peta = petaWaktuSholat(jadwalHari);

      for (int i = 0; i < urutanWaktuSholat.length; i++) {
        final waktu = peta[urutanWaktuSholat[i]];

        if (waktu == null || !waktu.isAfter(saat)) continue;

        rencana.add(
          JadwalAdzan(
            id: idAdzan(i, h),
            namaWaktu: urutanWaktuSholat[i],
            waktu: waktu,
            hariKe: h,
          ),
        );
      }
    }

    return rencana;
  }

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

  /// Menjadwalkan adzan untuk [hariAdzanKeDepan] hari ke depan.
  ///
  /// Tiap hari memakai JAM HARI ITU — bukan satu jam tetap yang diulang — jadi
  /// adzan tetap tepat walau jadwal sholat bergeser sedikit tiap hari.
  ///
  /// Pemasangan ulang hanya dilakukan kalau memang perlu: cakupannya sudah
  /// pendek, atau user pindah area. Kalau masih utuh, fungsi ini langsung
  /// kembali tanpa memasang ulang ratusan alarm.
  Future<void> schedulePrayerNotifications(
    PrayerTimes prayerTimes, {
    bool paksa = false,
  }) async {
    if (!isSupported) return;
    await init();

    final prefs = await SharedPreferences.getInstance();
    final enableAzan = prefs.getBool('enable_azan') ?? true;

    if (!enableAzan) {
      await cancelAdzanNotifications();
      await prefs.remove(_adzanSampaiKey);
      return;
    }

    // Simpan jadwal HARI INI. Dipakai pusat notifikasi & halaman Pengaturan
    // untuk menampilkan jam tiap waktu sholat.
    try {
      await prefs.setString(
        _prayerTimesKey,
        jsonEncode(
          petaWaktuSholat(
            prayerTimes,
          ).map((k, v) => MapEntry(k, v.toIso8601String())),
        ),
      );
    } catch (e) {
      debugPrint('Gagal menyimpan jadwal sholat: $e');
    }

    final koordinatBaru = _kunciKoordinat(prayerTimes.coordinates);
    final koordinatLama = prefs.getString(_adzanKoordinatKey);

    // `koordinatLama == null` berarti belum pernah dipasang → harus dipasang.
    final pindahArea = koordinatLama != null && koordinatLama != koordinatBaru;

    if (!paksa && !pindahArea && _cakupanMasihCukup(prefs)) {
      return;
    }

    await prefs.setString(_adzanKoordinatKey, koordinatBaru);

    // Bersihkan jadwal adzan lama supaya tidak dobel.
    //
    // ⚠️ JANGAN memakai `cancelAll()` di sini. Fungsi ini dipanggil setiap
    // kali aplikasi dibuka, dan `cancelAll()` ikut menghapus pengingat
    // dzikir pagi/sore yang sudah terjadwal (bug yang pernah terjadi).
    await cancelAdzanNotifications();

    final rencana = rencanaJadwalAdzan(prayerTimes);

    // Dipasang berurutan, bukan sekaligus bersamaan, supaya beban AlarmManager
    // tidak melonjak di HP kelas bawah.
    for (final jadwal in rencana) {
      await _jadwalkanDenganCadangan(
        id: jadwal.id,
        judul: 'Waktu Sholat ${jadwal.namaWaktu}',
        isi: 'Sudah masuk waktu sholat ${jadwal.namaWaktu}',
        target: tz.TZDateTime.from(jadwal.waktu, tz.local),
        details: _azanDetails(jadwal.namaWaktu),
        payload: 'prayer:${jadwal.namaWaktu}',
        label: 'Adzan ${jadwal.namaWaktu}',
        berulang: false,
        catatSukses: false,
      );
    }

    final akhir = DateTime.now().add(
      const Duration(days: hariAdzanKeDepan - 1),
    );
    await prefs.setString(_adzanSampaiKey, _formatTanggal(akhir));

    debugPrint(
      '[Notif] ${rencana.length} alarm adzan dipasang, mencakup sampai '
      '${_formatTanggal(akhir)}',
    );
  }

  /// Apakah cakupan jadwal adzan yang tersimpan masih cukup panjang.
  bool _cakupanMasihCukup(SharedPreferences prefs) {
    final tersimpan = prefs.getString(_adzanSampaiKey);
    if (tersimpan == null) return false;

    final akhir = DateTime.tryParse(tersimpan);
    if (akhir == null) return false;

    final batas = DateTime.now().add(
      const Duration(days: hariAdzanKeDepan - _sisaHariIsiUlang),
    );

    return !akhir.isBefore(batas);
  }

  /// Kunci koordinat untuk mendeteksi perpindahan area.
  ///
  /// Dibulatkan 2 desimal (≈1 km) supaya goyangan GPS beberapa meter tidak
  /// dianggap pindah area — kalau tidak, ratusan alarm akan dipasang ulang
  /// setiap aplikasi dibuka.
  static String _kunciKoordinat(Coordinates k) =>
      '${k.latitude.toStringAsFixed(2)},${k.longitude.toStringAsFixed(2)}';

  /// Tanggal `yyyy-MM-dd` waktu lokal.
  static String _formatTanggal(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  /// Memasang ulang jadwal adzan TANPA meminta lokasi lagi.
  ///
  /// Dipakai halaman Pengaturan saat user menyalakan kembali toggle adzan.
  /// Koordinatnya diambil dari jadwal yang terakhir dipasang. Kalau belum
  /// pernah ada (mis. GPS belum pernah berhasil), tidak ada yang bisa
  /// dipasang — halaman utama akan memasangnya begitu lokasi didapat.
  Future<void> rescheduleFromSavedPrayerTimes() async {
    if (!isSupported) return;
    await init();

    final prefs = await SharedPreferences.getInstance();
    final tersimpan = prefs.getString(_adzanKoordinatKey);
    if (tersimpan == null) return;

    final bagian = tersimpan.split(',');
    if (bagian.length != 2) return;

    final lat = double.tryParse(bagian[0]);
    final lon = double.tryParse(bagian[1]);
    if (lat == null || lon == null) return;

    await schedulePrayerNotifications(
      PrayerTimes.today(Coordinates(lat, lon), parameterSholat()),
      paksa: true,
    );
  }

  /// Detail notifikasi adzan untuk satu waktu sholat.
  ///
  /// Dipisah supaya jalur TERJADWAL (alarm sistem) dan jalur
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
  /// [berulang] `true` = diulang tiap hari pada jam yang sama (dipakai
  /// pengingat dzikir 09:00/17:00). `false` = SEKALI saja pada tanggal & jam
  /// persis — ini yang dipakai adzan, supaya tiap hari memakai jamnya sendiri.
  ///
  /// [catatSukses] diisi `false` saat memasang ratusan alarm sekaligus, supaya
  /// log tidak dibanjiri ratusan baris. Kegagalan tetap selalu dicatat, dan
  /// keberhasilan yang butuh mode cadangan pun tetap dicatat.
  ///
  /// Mengembalikan `true` kalau benar-benar berhasil dipasang. Pemanggil yang
  /// menyimpan daftar ID (mis. pengingat runtutan) butuh nilai ini supaya
  /// hanya mencatat notifikasi yang nyata terpasang.
  Future<bool> _jadwalkanDenganCadangan({
    required int id,
    required String judul,
    required String isi,
    required tz.TZDateTime target,
    required NotificationDetails details,
    required String label,
    String? payload,
    bool berulang = true,
    bool catatSukses = true,
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
          matchDateTimeComponents: berulang ? DateTimeComponents.time : null,
          payload: payload,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        if (catatSukses || mode != AndroidScheduleMode.alarmClock) {
          debugPrint('[Notif] $label dijadwalkan ($mode) pada $target');
        }
        return true;
      } catch (e) {
        lastError = e;
        debugPrint('[Notif] Gagal jadwalkan $label dengan $mode: $e');
      }
    }

    debugPrint('[Notif] $label GAGAL dijadwalkan. Error terakhir: $lastError');
    return false;
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
  /// ID notifikasinya sengaja BERBEDA dari jalur terjadwal
  /// ([idAdzanLangsung]), supaya menampilkan adzan sekarang tidak menghapus
  /// alarm terjadwal — dan sebaliknya.
  Future<bool> showAdzanNow(String namaWaktu) async {
    if (!isSupported) return false;

    final index = urutanWaktuSholat.indexOf(namaWaktu);
    if (index < 0) return false;

    try {
      await init();
      await _notifications.show(
        idAdzanLangsung(index),
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

  /// Membatalkan alarm adzan [namaWaktu] yang belum berbunyi HARI INI.
  ///
  /// Dipakai tak lama SEBELUM waktu sholat masuk saat aplikasi sedang dibuka.
  /// Tujuannya supaya alarm sistem tidak berbunyi bersamaan dengan
  /// [showAdzanNow] (adzan dua kali di saat yang sama).
  ///
  /// Hanya slot HARI INI yang dibatalkan — alarm untuk hari-hari berikutnya
  /// tetap terpasang, jadi tidak ada lagi "rantai" yang perlu disambung.
  Future<void> batalkanAdzanTertunda(String namaWaktu) async {
    if (!isSupported) return;

    final index = urutanWaktuSholat.indexOf(namaWaktu);
    if (index < 0) return;

    await _cancellAman(idAdzan(index, 0));
  }

  /// Memastikan jadwal adzan masih utuh.
  ///
  /// ⚠️ Dulu fungsi ini WAJIB dipanggil setelah [batalkanAdzanTertunda], karena
  /// jadwalnya dipasang sebagai SATU alarm berulang yang harus "disambung"
  /// ulang tiap hari. Sekarang seluruh jadwal [hariAdzanKeDepan] hari sudah
  /// terpasang sejak awal, jadi yang perlu dilakukan hanya memastikan
  /// cakupannya masih utuh — dan kalau masih utuh, langsung kembali tanpa
  /// kerja apa pun.
  Future<void> pastikanJadwalAdzanUtuh() async {
    if (!isSupported) return;

    final prefs = await SharedPreferences.getInstance();
    if (_cakupanMasihCukup(prefs)) return;

    // Cakupan sudah pendek: pasang ulang memakai koordinat yang tersimpan.
    await rescheduleFromSavedPrayerTimes();
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
    await _cancellAman(_dzikirPagiReminderId);
    await _cancellAman(_dzikirSoreReminderId);

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
  // PENGINGAT JADWAL KAJIAN
  // ===================================================================
  /// Menyusun daftar pengingat kajian untuk [hari] hari ke depan.
  ///
  /// ⚠️ Fungsi ini SENGAJA MURNI — tidak menyentuh plugin notifikasi — supaya
  /// rencananya bisa diuji tanpa HP (lihat `test/pengingat_kajian_test.dart`).
  ///
  /// Tiap kajian menghasilkan DUA pengingat:
  /// 1. [menitPengingatKajian] menit sebelum jam mulai,
  /// 2. tepat saat jam mulai.
  ///
  /// Yang sudah lewat tidak ikut dijadwalkan — tapi keduanya diperiksa
  /// TERPISAH. Kalau user membuka aplikasi 10 menit sebelum kajian dimulai,
  /// pengingat H-30 sudah lewat (tidak dipasang) sedangkan pengingat saat
  /// mulai masih dipasang. Itu justru yang paling dibutuhkan saat itu.
  static List<PengingatKajian> rencanaPengingatKajian(
    List<KajianRingkas> daftar, {
    DateTime? sekarang,
    int hari = hariKajianKeDepan,
  }) {
    final saat = sekarang ?? DateTime.now();
    final awalHari = DateTime(saat.year, saat.month, saat.day);
    final rencana = <PengingatKajian>[];

    // Diurutkan supaya penomoran ID di dalam satu hari selalu sama untuk
    // daftar yang sama (ID harus stabil, kalau tidak jadwal lama bisa
    // tertinggal di sistem).
    final urut = List<KajianRingkas>.from(daftar)
      ..sort((a, b) => a.mulai.compareTo(b.mulai));

    final nomorDalamHari = <String, int>{};

    for (final kajian in urut) {
      final tanggalKajian = DateTime(
        kajian.mulai.year,
        kajian.mulai.month,
        kajian.mulai.day,
      );
      final selisihHari = tanggalKajian.difference(awalHari).inDays;

      if (selisihHari < 0 || selisihHari >= hari) continue;

      final kunciHari = _formatTanggal(tanggalKajian);
      final nomor = nomorDalamHari[kunciHari] ?? 0;
      if (nomor >= _kajianMaksPerHari) continue;
      nomorDalamHari[kunciHari] = nomor + 1;

      final idH30 = _kajianIdDasar + selisihHari * _kajianIdPerHari + nomor * 2;
      final idMulai = idH30 + 1;

      final waktuH30 = kajian.mulai.subtract(
        const Duration(minutes: menitPengingatKajian),
      );

      if (waktuH30.isAfter(saat)) {
        rencana.add(
          PengingatKajian(
            id: idH30,
            kajian: kajian,
            waktu: waktuH30,
            jenis: JenisPengingatKajian.h30,
          ),
        );
      }

      if (kajian.mulai.isAfter(saat)) {
        rencana.add(
          PengingatKajian(
            id: idMulai,
            kajian: kajian,
            waktu: kajian.mulai,
            jenis: JenisPengingatKajian.mulai,
          ),
        );
      }
    }

    return rencana;
  }

  /// Memasang pengingat untuk seluruh [daftar] kajian yang akan datang.
  ///
  /// Aman dipanggil berkali-kali: jadwal lama dibatalkan lebih dulu, jadi
  /// tidak ada pengingat ganda. Dipanggil setiap kali daftar kajian selesai
  /// diambil dari API (`/api/kajian`), karena admin bisa menambah, mengubah,
  /// atau menghapus jadwal kapan saja.
  Future<void> scheduleKajianReminders(List<KajianRingkas> daftar) async {
    if (!isSupported) return;
    await init();

    final prefs = await SharedPreferences.getInstance();
    final aktif = prefs.getBool(_pengingatKajianKey) ?? true;

    // Selalu dibatalkan dulu. Daftar kajian bisa berubah kapan saja, jadi
    // jadwal lama tidak boleh tertinggal (mis. kajian yang sudah dihapus
    // admin tapi pengingatnya masih berbunyi).
    await batalPengingatKajian();

    if (!aktif) {
      debugPrint('[Kajian] Pengingat jadwal kajian dimatikan user');
      return;
    }

    final rencana = rencanaPengingatKajian(daftar);

    for (final pengingat in rencana) {
      final k = pengingat.kajian;
      final jamMulai = _formatJam(k.mulai);

      await _jadwalkanDenganCadangan(
        id: pengingat.id,
        judul: pengingat.jenis == JenisPengingatKajian.h30
            ? '⏰ $menitPengingatKajian menit lagi: kajian akan dimulai'
            : '🔴 Kajian sedang dimulai',
        isi: _ringkasPengingatKajian(k),
        target: tz.TZDateTime.from(pengingat.waktu, tz.local),
        details: NotificationDetails(
          android: AndroidNotificationDetails(
            kajianReminderChannelId,
            _kajianReminderChannelName,
            channelDescription: _kajianReminderChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.reminder,
            ticker: pengingat.jenis == JenisPengingatKajian.h30
                ? 'Kajian akan dimulai'
                : 'Kajian dimulai',
            styleInformation: BigTextStyleInformation(
              _detailPengingatKajian(k, pengingat.jenis),
            ),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
        payload: 'kajian_reminder:${pengingat.id}',
        label:
            'Pengingat kajian "${k.judul}" (${pengingat.jenis == JenisPengingatKajian.h30 ? 'H-$menitPengingatKajian' : 'mulai'} $jamMulai)',
        berulang: false,
        catatSukses: false,
      );
    }

    // Daftar ID disimpan supaya pembatalan berikutnya hanya menyentuh yang
    // benar-benar terpasang, dan daftar kajiannya disimpan supaya toggle di
    // Pengaturan bisa memasang ulang tanpa memanggil API.
    await prefs.setString(
      _kajianTerjadwalKey,
      jsonEncode(rencana.map((p) => p.id).toList()),
    );
    await prefs.setString(
      _kajianDaftarKey,
      jsonEncode(daftar.map((k) => k.toJson()).toList()),
    );

    debugPrint(
      '[Kajian] ${rencana.length} pengingat dipasang '
      'dari ${daftar.length} kajian dalam $hariKajianKeDepan hari',
    );
  }

  /// Memasang ulang pengingat dari daftar kajian yang TERSIMPAN.
  ///
  /// Dipakai halaman Pengaturan saat user menyalakan kembali toggle pengingat:
  /// tidak perlu memanggil API lagi, cukup memakai jadwal terakhir yang sudah
  /// didapat. Kalau belum pernah ada (mis. aplikasi baru dibuka dan data
  /// kajian belum sempat diambil), tidak ada yang bisa dipasang — Home akan
  /// memasangnya begitu data kajian tiba.
  Future<void> rescheduleKajianRemindersFromSaved() async {
    if (!isSupported) return;
    await init();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kajianDaftarKey);
    if (raw == null) return;

    List<KajianRingkas> daftar;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      daftar = decoded
          .whereType<Map<String, dynamic>>()
          .map(KajianRingkas.dariJsonTersimpan)
          .whereType<KajianRingkas>()
          .toList();
    } catch (e) {
      debugPrint('[Kajian] Gagal membaca daftar kajian tersimpan: $e');
      return;
    }

    await scheduleKajianReminders(daftar);
  }

  /// Membatalkan SEMUA pengingat kajian yang pernah dipasang.
  ///
  /// Hanya membatalkan ID yang tercatat di [_kajianTerjadwalKey] — jauh lebih
  /// hemat daripada menyapu seluruh rentang 2300–2899 setiap kali jadwal
  /// diperbarui.
  Future<void> batalPengingatKajian() async {
    if (!isSupported) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kajianTerjadwalKey);

    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        for (final nilai in decoded) {
          final id = int.tryParse(nilai.toString());
          if (id != null) await _cancellAman(id);
        }
      } catch (e) {
        debugPrint('[Kajian] Gagal membaca daftar ID pengingat kajian: $e');
      }
    }

    await prefs.remove(_kajianTerjadwalKey);
  }

  /// Berapa pengingat kajian yang sedang terpasang. Dipakai kartu "Status
  /// Notifikasi" di halaman Pengaturan.
  Future<int> jumlahPengingatKajian() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kajianTerjadwalKey);
    if (raw == null) return 0;
    try {
      return (jsonDecode(raw) as List<dynamic>).length;
    } catch (e) {
      return 0;
    }
  }

  // ===================================================================
  // PENGINGAT PENYELAMAT RUNTUTAN
  // ===================================================================
  /// Memasang SATU pengingat runtutan.
  ///
  /// Dijadwalkan pada tanggal & jam persis (`berulang: false`), sama seperti
  /// adzan — jadi tiap hari punya notifikasinya sendiri dan hari yang sudah
  /// tuntas bisa dibatalkan satu-satu.
  ///
  /// Mengembalikan `true` kalau benar-benar berhasil dipasang, supaya
  /// pemanggilnya hanya menyimpan ID yang nyata terpasang.
  Future<bool> jadwalkanPengingatStreak(PengingatStreak pengingat) async {
    if (!isSupported) return false;

    return _jadwalkanDenganCadangan(
      id: pengingat.id,
      judul: pengingat.judul,
      isi: pengingat.isi,
      target: tz.TZDateTime.from(pengingat.waktu, tz.local),
      details: NotificationDetails(
        android: AndroidNotificationDetails(
          streakChannelId,
          _streakChannelName,
          channelDescription: _streakChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.reminder,
          ticker: 'Runtutan harian belum tuntas',
          styleInformation: BigTextStyleInformation(pengingat.isi),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
      payload: 'streak:',
      label: 'Pengingat runtutan',
      berulang: false,
      catatSukses: false,
    );
  }

  /// Menyimpan daftar ID pengingat runtutan yang berhasil dipasang.
  Future<void> simpanIdPengingatStreak(List<int> id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_streakTerjadwalKey, jsonEncode(id));
  }

  /// Membatalkan SEMUA pengingat runtutan yang pernah dipasang.
  Future<void> batalPengingatStreak() async {
    if (!isSupported) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_streakTerjadwalKey);

    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        for (final nilai in decoded) {
          final id = int.tryParse(nilai.toString());
          if (id != null) await _cancellAman(id);
        }
      } catch (e) {
        debugPrint('[Streak] Gagal membaca daftar ID pengingat runtutan: $e');
      }
    }

    await prefs.remove(_streakTerjadwalKey);
  }

  /// Satu baris ringkas untuk laci notifikasi, contoh:
  /// `kitab al bidayah wa an nihayah • Ustadz Dr Muamar Ma'ruf MA. • mulai 09:15`.
  static String _ringkasPengingatKajian(KajianRingkas k) {
    final bagian = <String>[k.judul];
    if (k.ustadz.trim().isNotEmpty) bagian.add(k.ustadz.trim());
    bagian.add('mulai ${_formatJam(k.mulai)}');
    return bagian.join(' • ');
  }

  /// Isi lengkap notifikasi (dipakai saat notifikasi dibentangkan).
  static String _detailPengingatKajian(
    KajianRingkas k,
    JenisPengingatKajian jenis,
  ) {
    final baris = <String>[k.judul];
    if (k.ustadz.trim().isNotEmpty) baris.add('Ustadz ${k.ustadz.trim()}');

    final waktu = jenis == JenisPengingatKajian.h30
        ? 'Dimulai pukul ${_formatJam(k.mulai)} '
              '($menitPengingatKajian menit dari sekarang)'
        : 'Sedang berlangsung sejak pukul ${_formatJam(k.mulai)}';
    baris.add(waktu);

    if (k.lokasi.trim().isNotEmpty) baris.add('Lokasi: ${k.lokasi.trim()}');

    return baris.join('\n');
  }

  /// Jam `HH:mm` waktu lokal.
  static String _formatJam(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

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
      for (final nama in urutanWaktuSholat) {
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
    try {
      await _notifications.cancelAll();
    } catch (e) {
      debugPrint('[Notif] Gagal membatalkan semua notifikasi: $e');
    }
  }

  /// Membatalkan SATU notifikasi tanpa membuat proses lain ikut gagal.
  ///
  /// Ini bukan sekadar kehati-hatian. Pernah kejadian: `cancel()` melempar
  /// `PlatformException` di build rilis karena bug Gson di dalam plugin (lihat
  /// `android/app/proguard-rules.pro`). Karena exception-nya dibiarkan naik,
  /// SELURUH penjadwalan adzan ikut batal dan adzan tidak pernah berbunyi.
  /// Satu pembatalan yang gagal tidak boleh mematikan fiturnya.
  Future<void> _cancellAman(int id) async {
    try {
      await _notifications.cancel(id);
    } catch (e) {
      debugPrint('[Notif] Gagal membatalkan notifikasi $id: $e');
    }
  }

  /// Membatalkan SELURUH notifikasi adzan: 5 waktu × [hariAdzanKeDepan] hari,
  /// plus sisa alarm versi lama (satu alarm berulang tiap hari).
  ///
  /// ⚠️ Jangan kembali memakai `cancelAll()` di jalur penjadwalan adzan:
  /// fungsi itu ikut menghapus pengingat dzikir dan notifikasi terjadwal lain.
  Future<void> cancelAdzanNotifications() async {
    if (!isSupported) return;

    // Sisa alarm versi LAMA. Kalau tidak dibatalkan, HP yang sudah memasang
    // versi sebelumnya akan berbunyi DUA KALI di waktu yang sama.
    for (final id in _adzanIdLama) {
      await _cancellAman(id);
    }

    for (int i = 0; i < urutanWaktuSholat.length; i++) {
      for (int hari = 0; hari < hariAdzanKeDepan; hari++) {
        await _cancellAman(idAdzan(i, hari));
      }
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

    // Dihitung per WAKTU SHOLAT (0–5), bukan jumlah baris alarm: sejak jadwal
    // dipasang [hariAdzanKeDepan] hari sekaligus, satu waktu sholat punya
    // puluhan alarm — sedangkan halaman Pengaturan menampilkan
    // "x dari 5 waktu sholat".
    final idTertunda = tertunda.map((n) => n.id).toSet();
    int adzanTerjadwal = 0;
    for (int i = 0; i < urutanWaktuSholat.length; i++) {
      final ada = List<int>.generate(
        hariAdzanKeDepan,
        (h) => idAdzan(i, h),
      ).any(idTertunda.contains);
      if (ada) adzanTerjadwal++;
    }

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

/// Satu alarm adzan yang harus dipasang di sistem.
///
/// Hasil dari [NotificationService.rencanaJadwalAdzan] — fungsi murni itu
/// menyusun daftar ini tanpa menyentuh plugin notifikasi, supaya rencananya
/// bisa diuji tanpa HP.
class JadwalAdzan {
  const JadwalAdzan({
    required this.id,
    required this.namaWaktu,
    required this.waktu,
    required this.hariKe,
  });

  /// ID notifikasi — lihat [NotificationService.idAdzan].
  final int id;

  final String namaWaktu;

  /// Waktu sholat yang TEPAT untuk hari tersebut.
  final DateTime waktu;

  /// 0 = hari ini, 1 = besok, dan seterusnya.
  final int hariKe;
}

/// Jenis pengingat kajian.
enum JenisPengingatKajian {
  /// [NotificationService.menitPengingatKajian] menit sebelum jam mulai.
  h30,

  /// Tepat saat jam mulai.
  mulai,
}

/// Data kajian seperlunya untuk memasang pengingat.
///
/// Sengaja TIDAK memakai model `Kajian` milik `kajian_screen.dart` supaya
/// service notifikasi tidak bergantung pada layar. Layar cukup mengubah
/// jawaban `/api/kajian` menjadi daftar ini lewat [dariMap].
class KajianRingkas {
  const KajianRingkas({
    required this.mulai,
    required this.judul,
    required this.ustadz,
    required this.lokasi,
  });

  /// Tanggal + jam mulai kajian, waktu lokal perangkat.
  final DateTime mulai;
  final String judul;
  final String ustadz;
  final String lokasi;

  /// Membaca satu item dari `/api/kajian`.
  ///
  /// Bentuk tanggal & jam disamakan dengan `Kajian.fromJson` di
  /// `kajian_screen.dart`: `tanggal` bisa berisi `2026-09-22T00:00:00Z` dan
  /// `jam_mulai` bisa berisi `18:45:00` — keduanya dipotong ke bagian yang
  /// dipakai. Dikembalikan `null` kalau tanggal/jamnya tidak bisa dibaca,
  /// supaya satu data rusak tidak menggagalkan seluruh penjadwalan.
  static KajianRingkas? dariMap(Map<String, dynamic> json) {
    final String tanggalRaw = json['tanggal']?.toString() ?? '';
    final String tanggal = tanggalRaw.contains('T')
        ? tanggalRaw.split('T').first
        : tanggalRaw;

    final String jamRaw = json['jam_mulai']?.toString() ?? '';
    final String jam = jamRaw.length >= 5 ? jamRaw.substring(0, 5) : jamRaw;

    final DateTime? mulai = DateTime.tryParse('$tanggal $jam:00');
    if (mulai == null) return null;

    return KajianRingkas(
      mulai: mulai,
      judul: json['judul']?.toString() ?? '',
      ustadz: json['ustadz']?.toString() ?? '',
      lokasi: json['lokasi']?.toString() ?? '',
    );
  }

  /// Untuk disimpan di SharedPreferences (lihat
  /// [NotificationService.rescheduleKajianRemindersFromSaved]).
  Map<String, dynamic> toJson() => <String, dynamic>{
    'mulai': mulai.toIso8601String(),
    'judul': judul,
    'ustadz': ustadz,
    'lokasi': lokasi,
  };

  /// Kebalikan dari [toJson].
  static KajianRingkas? dariJsonTersimpan(Map<String, dynamic> json) {
    final DateTime? mulai = DateTime.tryParse(json['mulai']?.toString() ?? '');
    if (mulai == null) return null;

    return KajianRingkas(
      mulai: mulai,
      judul: json['judul']?.toString() ?? '',
      ustadz: json['ustadz']?.toString() ?? '',
      lokasi: json['lokasi']?.toString() ?? '',
    );
  }
}

/// Satu pengingat kajian yang harus dipasang di sistem.
///
/// Hasil dari [NotificationService.rencanaPengingatKajian] — fungsi murni itu
/// menyusun daftar ini tanpa menyentuh plugin notifikasi, supaya rencananya
/// bisa diuji tanpa HP (`test/pengingat_kajian_test.dart`).
class PengingatKajian {
  const PengingatKajian({
    required this.id,
    required this.kajian,
    required this.waktu,
    required this.jenis,
  });

  /// ID notifikasi, di dalam rentang blok pengingat kajian.
  final int id;

  final KajianRingkas kajian;

  /// Kapan notifikasi harus berbunyi.
  final DateTime waktu;

  final JenisPengingatKajian jenis;
}

/// Satu pengingat penyelamat runtutan yang harus dipasang di sistem.
///
/// Hasil dari `StreakService.rencanaPengingatStreak` — fungsi murni itu
/// menyusun daftar ini tanpa menyentuh plugin notifikasi, supaya rencananya
/// bisa diuji tanpa HP.
///
/// Diletakkan di sini (bukan di `streak_service.dart`) karena
/// [NotificationService.jadwalkanPengingatStreak] menerimanya sebagai
/// parameter. Kalau kelasnya ditaruh di sana, kedua berkas itu saling
/// mengimpor — dan itu membingungkan tanpa manfaat.
class PengingatStreak {
  const PengingatStreak({
    required this.id,
    required this.waktu,
    required this.judul,
    required this.isi,
  });

  final int id;
  final DateTime waktu;
  final String judul;
  final String isi;
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
