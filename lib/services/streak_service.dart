import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

/// Aturan runtutan harian (streak) untuk **dzikir** 🔥 dan **baca Al-Qur'an** 📖.
///
/// Dua runtutan dihitung TERPISAH, sesuai keputusan user 29 Sep 2026:
///
/// | | Dihitung tuntas kalau |
/// |---|---|
/// | 🔥 Dzikir | dzikir **pagi DAN sore** sama-sama selesai hari itu |
/// | 📖 Quran | **10 ayat** di mode terjemahan **atau** **1 halaman** di mode mushaf |
///
/// Toleransi: runtutan **tidak** putus kalau cuma bolong 1–3 hari. Bolong
/// sampai hari ke-4 baru dihitung putus (lihat [toleransiHariBolong]).
///
/// ⚠️ Penyimpanannya **LOKAL** (SharedPreferences), bukan di akun. Alasannya
/// aplikasi bisa dipakai tanpa login (Mode Tamu), jadi tidak selalu ada akun
/// untuk menempelkan datanya. Konsekuensinya: runtutan hilang kalau aplikasi
/// dipasang ulang atau berganti HP. Itu disengaja.
class StreakService {
  static final StreakService _instance = StreakService._internal();
  factory StreakService() => _instance;
  StreakService._internal();

  /// Berapa hari bolong yang masih dimaafkan.
  ///
  /// Diperiksa lewat JARAK antar tanggal, bukan jumlah hari bolong:
  /// selisih 1 hari = beruntun, selisih 4 hari = bolong 3 hari (masih aman),
  /// selisih 5 hari = bolong 4 hari (putus).
  /// Jadi batasnya `selisih <= toleransiHariBolong + 1`.
  static const int toleransiHariBolong = 3;

  /// Target baca harian di mode terjemahan.
  static const int ayatMinimalTerjemahan = 10;

  /// Target baca harian di mode mushaf.
  static const int halamanMinimalMushaf = 1;

  /// Toggle di halaman Pengaturan: pengingat penyelamat runtutan.
  static const String _pengingatKey = 'enable_streak_reminder';

  /// Prefs: sidik (sidik jari) keadaan terakhir yang sudah dipakai memasang
  /// pengingat, supaya pemasangan tidak diulang-ulang tanpa perubahan.
  static const String _sidikPengingatKey = 'streak_pengingat_sidik';

  // --- Prefs: penanda penyelesaian dzikir harian ---
  static const String _dzikirPagiKey = 'streak_dzikir_pagi_tanggal';
  static const String _dzikirSoreKey = 'streak_dzikir_sore_tanggal';

  // --- Prefs: runtutan yang tersimpan ---
  static const String _runtutanDzikirKey = 'streak_dzikir_jumlah';
  static const String _runtutanDzikirTerakhirKey = 'streak_dzikir_terakhir';
  static const String _runtutanQuranKey = 'streak_quran_jumlah';
  static const String _runtutanQuranTerakhirKey = 'streak_quran_terakhir';

  // --- Prefs: progres baca Al-Qur'an hari ini ---
  static const String _quranTanggalKey = 'streak_quran_progres_tanggal';
  static const String _quranAyatKey = 'streak_quran_ayat_hari_ini';
  static const String _quranHalamanKey = 'streak_quran_halaman_hari_ini';

  // =====================================================================
  // LOGIKA MURNI — bisa diuji tanpa HP (lihat test/streak_test.dart)
  // =====================================================================

  /// Tanggal tanpa jam, supaya selisih hari tidak terpengaruh jam.
  static DateTime hari(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Apakah [terakhir] masih terhitung "belum putus" pada [hariIni].
  ///
  /// Dipakai dua-duanya: untuk MENGHITUNG runtutan baru, dan untuk MENAMPILKAN
  /// runtutan yang masih berlaku. Sengaja satu fungsi supaya keduanya tidak
  /// pernah berbeda pendapat.
  static bool masihMenyambung(DateTime terakhir, DateTime hariIni) {
    final int selisih = hari(hariIni).difference(hari(terakhir)).inDays;
    return selisih <= toleransiHariBolong + 1;
  }

  /// Runtutan baru setelah user menuntaskan targetnya pada [hariIni].
  ///
  /// - belum pernah tuntas → mulai dari 1
  /// - sudah dihitung hari ini → tidak ditambah (mencegah dobel)
  /// - masih menyambung → ditambah 1
  /// - sudah kelewat toleransi → mulai lagi dari 1 (runtutan lama hangus)
  static int hitungRuntutanBaru({
    required int runtutanSekarang,
    required DateTime? terakhirSelesai,
    required DateTime hariIni,
  }) {
    if (terakhirSelesai == null) return 1;

    final int selisih = hari(hariIni).difference(hari(terakhirSelesai)).inDays;

    // Sudah dituntaskan hari ini (atau tanggal tersimpannya "di depan"
    // karena jam HP pernah diubah) — jangan dihitung dua kali.
    if (selisih <= 0) return runtutanSekarang <= 0 ? 1 : runtutanSekarang;

    if (masihMenyambung(terakhirSelesai, hariIni)) {
      return (runtutanSekarang <= 0 ? 0 : runtutanSekarang) + 1;
    }

    return 1;
  }

  /// Runtutan yang masih berlaku untuk ditampilkan.
  ///
  /// Mengembalikan 0 kalau user sudah meninggalkan runtutannya terlalu lama,
  /// TANPA perlu menulis apa pun. Jadi runtutan bisa "terlihat putus" sendiri
  /// begitu aplikasi dibuka lagi setelah lama tidak dipakai.
  static int runtutanBerlaku({
    required int runtutanTersimpan,
    required DateTime? terakhirSelesai,
    required DateTime hariIni,
  }) {
    if (terakhirSelesai == null || runtutanTersimpan <= 0) return 0;
    if (!masihMenyambung(terakhirSelesai, hariIni)) return 0;
    return runtutanTersimpan;
  }

  /// Apakah target ayat mode terjemahan sudah tercukupi.
  static bool ayatSudahCukup(int ayatHariIni) =>
      ayatHariIni >= ayatMinimalTerjemahan;

  /// Apakah target halaman mode mushaf sudah tercukupi.
  static bool halamanSudahCukup(int halamanHariIni) =>
      halamanHariIni >= halamanMinimalMushaf;

  /// Apakah target baca Al-Qur'an hari ini sudah tercukupi (salah satu mode).
  static bool quranSudahCukup({
    required int ayatHariIni,
    required int halamanHariIni,
  }) => ayatSudahCukup(ayatHariIni) || halamanSudahCukup(halamanHariIni);

  /// Menyusun daftar pengingat penyelamat runtutan untuk beberapa hari ke depan.
  ///
  /// Hanya dipasang pada jam [NotificationService.jamPengingatStreak], dan
  /// HARI INI dilewati kalau semuanya sudah tuntas — supaya tidak ada
  /// pengingat yang berbunyi untuk pekerjaan yang sudah selesai.
  ///
  /// Fungsi murni: tidak menyentuh plugin notifikasi.
  static List<PengingatStreak> rencanaPengingatStreak({
    required bool hariIniTuntas,
    required bool dzikirTuntas,
    required bool quranTuntas,
    required int runtutanTertinggi,
    DateTime? sekarang,
    int hariKeDepan = NotificationService.hariPengingatStreakKeDepan,
  }) {
    final saat = sekarang ?? DateTime.now();
    final rencana = <PengingatStreak>[];

    for (int h = 0; h < hariKeDepan; h++) {
      // Hari ini tidak perlu dijadwalkan kalau sudah beres semuanya.
      if (h == 0 && hariIniTuntas) continue;

      final tanggal = hari(saat).add(Duration(days: h));
      rencana.add(
        PengingatStreak(
          id: NotificationService.idPengingatStreak(h),
          waktu: DateTime(
            tanggal.year,
            tanggal.month,
            tanggal.day,
            NotificationService.jamPengingatStreak,
          ),
          judul: runtutanTertinggi > 0
              ? '🔥 Runtutanmu belum tuntas hari ini'
              : '🔥 Yuk mulai runtutan hari ini',
          isi: _isiPengingatStreak(
            runtutanTertinggi: runtutanTertinggi,
            dzikirTuntas: h == 0 && dzikirTuntas,
            quranTuntas: h == 0 && quranTuntas,
          ),
        ),
      );
    }

    return rencana;
  }

  /// Isi notifikasi, disesuaikan dengan apa yang MASIH kurang.
  static String _isiPengingatStreak({
    required int runtutanTertinggi,
    required bool dzikirTuntas,
    required bool quranTuntas,
  }) {
    final sisa = <String>[
      if (!dzikirTuntas) 'dzikir pagi & sore',
      if (!quranTuntas)
        '$ayatMinimalTerjemahan ayat atau $halamanMinimalMushaf halaman',
    ];

    if (sisa.isEmpty) {
      return 'Alhamdulillah, semua sudah tuntas hari ini. 🌙';
    }

    final pembuka = runtutanTertinggi > 0
        ? 'Runtutan $runtutanTertinggi hari bisa putus kalau hari ini terlewat. '
        : 'Belum ada runtutan hari ini. ';

    return '${pembuka}Tinggal ${sisa.join(' dan ')}.';
  }

  // =====================================================================
  // DZIKIR
  // =====================================================================

  /// Mencatat bahwa dzikir [isPagi] sudah tuntas HARI INI.
  ///
  /// Dipanggil dari halaman Dzikir. Penanda tanggalnya disimpan supaya
  /// perayaan & notifikasi hanya muncul SEKALI per hari — sebelumnya penanda
  /// ini hanya ada di memori, jadi menutup lalu membuka aplikasi membuat
  /// perayaannya muncul lagi (dan notifikasinya terkirim dua kali).
  Future<void> tandaiDzikirSelesai({required bool isPagi}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      isPagi ? _dzikirPagiKey : _dzikirSoreKey,
      _formatTanggal(DateTime.now()),
    );
    await _perbaruiRuntutanDzikir();
    await pastikanPengingatStreak();
  }

  /// Apakah dzikir [isPagi] sudah ditandai tuntas hari ini.
  Future<bool> dzikirSudahDitandai({required bool isPagi}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(isPagi ? _dzikirPagiKey : _dzikirSoreKey) ==
        _formatTanggal(DateTime.now());
  }

  /// Apakah dzikir pagi DAN sore sudah tuntas hari ini.
  Future<bool> dzikirHariIniTuntas() async {
    final prefs = await SharedPreferences.getInstance();
    final hariIni = _formatTanggal(DateTime.now());
    return prefs.getString(_dzikirPagiKey) == hariIni &&
        prefs.getString(_dzikirSoreKey) == hariIni;
  }

  /// Menambah runtutan dzikir kalau hari ini sudah pagi + sore.
  Future<void> _perbaruiRuntutanDzikir() async {
    if (!await dzikirHariIniTuntas()) return;

    final prefs = await SharedPreferences.getInstance();
    await _catatRuntutan(
      prefs: prefs,
      kunciJumlah: _runtutanDzikirKey,
      kunciTerakhir: _runtutanDzikirTerakhirKey,
    );
  }

  // =====================================================================
  // BACA AL-QUR'AN
  // =====================================================================

  /// Menambah jumlah ayat yang dibaca hari ini (mode terjemahan).
  ///
  /// [jumlah] adalah banyaknya ayat BARU yang terlewati, bukan nomor ayat —
  /// jadi membaca lanjutan di ayat 255 tetap menambah 1 per ayat.
  Future<void> tambahAyatDibaca(int jumlah) async {
    if (jumlah <= 0) return;
    await _tambahProgresQuran(_quranAyatKey, jumlah);
  }

  /// Menambah jumlah halaman yang dibaca hari ini (mode mushaf).
  Future<void> tambahHalamanDibaca(int jumlah) async {
    if (jumlah <= 0) return;
    await _tambahProgresQuran(_quranHalamanKey, jumlah);
  }

  Future<void> _tambahProgresQuran(String kunci, int jumlah) async {
    final prefs = await SharedPreferences.getInstance();
    final hariIni = _formatTanggal(DateTime.now());

    // Hari baru → hitungannya mulai dari nol lagi.
    if (prefs.getString(_quranTanggalKey) != hariIni) {
      await prefs.setString(_quranTanggalKey, hariIni);
      await prefs.setInt(_quranAyatKey, 0);
      await prefs.setInt(_quranHalamanKey, 0);
    }

    final bool cukupSebelum = quranSudahCukup(
      ayatHariIni: prefs.getInt(_quranAyatKey) ?? 0,
      halamanHariIni: prefs.getInt(_quranHalamanKey) ?? 0,
    );

    await prefs.setInt(kunci, (prefs.getInt(kunci) ?? 0) + jumlah);

    final bool cukupSesudah = quranSudahCukup(
      ayatHariIni: prefs.getInt(_quranAyatKey) ?? 0,
      halamanHariIni: prefs.getInt(_quranHalamanKey) ?? 0,
    );

    // Begitu target tercukupi, runtutan Quran hari ini langsung dicatat.
    if (cukupSesudah) {
      await _catatRuntutan(
        prefs: prefs,
        kunciJumlah: _runtutanQuranKey,
        kunciTerakhir: _runtutanQuranTerakhirKey,
      );
    }

    // Pengingat hanya ditata ulang kalau statusnya MEMANG BERUBAH.
    // Tanpa penjagaan ini, setiap ayat baru yang terlewati akan membatalkan
    // dan memasang ulang tujuh notifikasi — pemborosan yang tidak perlu.
    if (cukupSesudah != cukupSebelum) await pastikanPengingatStreak();
  }

  /// Progres baca Al-Qur'an hari ini.
  Future<ProgresQuran> progresQuranHariIni() async {
    final prefs = await SharedPreferences.getInstance();
    final hariIni = _formatTanggal(DateTime.now());

    if (prefs.getString(_quranTanggalKey) != hariIni) {
      return const ProgresQuran(ayat: 0, halaman: 0);
    }

    return ProgresQuran(
      ayat: prefs.getInt(_quranAyatKey) ?? 0,
      halaman: prefs.getInt(_quranHalamanKey) ?? 0,
    );
  }

  /// Apakah target baca Al-Qur'an hari ini sudah tercukupi.
  Future<bool> quranHariIniTuntas() async {
    final progres = await progresQuranHariIni();
    return quranSudahCukup(
      ayatHariIni: progres.ayat,
      halamanHariIni: progres.halaman,
    );
  }

  // =====================================================================
  // RUNTUTAN
  // =====================================================================

  /// Mencatat runtutan untuk hari ini pada pasangan kunci tertentu.
  ///
  /// Aman dipanggil berkali-kali dalam sehari: [hitungRuntutanBaru] tidak
  /// menambah kalau tanggal terakhirnya sudah hari ini.
  Future<void> _catatRuntutan({
    required SharedPreferences prefs,
    required String kunciJumlah,
    required String kunciTerakhir,
  }) async {
    final DateTime sekarang = DateTime.now();
    final DateTime? terakhir = _parseTanggal(prefs.getString(kunciTerakhir));

    final int jumlah = hitungRuntutanBaru(
      runtutanSekarang: prefs.getInt(kunciJumlah) ?? 0,
      terakhirSelesai: terakhir,
      hariIni: sekarang,
    );

    await prefs.setInt(kunciJumlah, jumlah);
    await prefs.setString(kunciTerakhir, _formatTanggal(sekarang));
  }

  /// Ringkasan runtutan untuk ditampilkan di halaman utama & Pengaturan.
  Future<RingkasanStreak> ringkasan() async {
    final prefs = await SharedPreferences.getInstance();
    final DateTime sekarang = DateTime.now();
    final String hariIni = _formatTanggal(sekarang);

    final bool pagiTuntas = prefs.getString(_dzikirPagiKey) == hariIni;
    final bool soreTuntas = prefs.getString(_dzikirSoreKey) == hariIni;
    final ProgresQuran progres = await progresQuranHariIni();

    return RingkasanStreak(
      dzikir: runtutanBerlaku(
        runtutanTersimpan: prefs.getInt(_runtutanDzikirKey) ?? 0,
        terakhirSelesai: _parseTanggal(
          prefs.getString(_runtutanDzikirTerakhirKey),
        ),
        hariIni: sekarang,
      ),
      quran: runtutanBerlaku(
        runtutanTersimpan: prefs.getInt(_runtutanQuranKey) ?? 0,
        terakhirSelesai: _parseTanggal(
          prefs.getString(_runtutanQuranTerakhirKey),
        ),
        hariIni: sekarang,
      ),
      pagiTuntas: pagiTuntas,
      soreTuntas: soreTuntas,
      dzikirHariIniTuntas: pagiTuntas && soreTuntas,
      progresQuran: progres,
    );
  }

  // =====================================================================
  // PENGINGAT PENYELAMAT RUNTUTAN
  // =====================================================================

  /// Apakah pengingat penyelamat runtutan aktif (bawaan: aktif).
  Future<bool> isPengingatAktif() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pengingatKey) ?? true;
  }

  /// Memasang ulang pengingat penyelamat runtutan.
  ///
  /// Aman dipanggil berkali-kali (mis. setiap kali progres berubah): jadwal
  /// lama dibatalkan lebih dulu. Dipanggil juga saat aplikasi dibuka supaya
  /// pengingatnya selalu mencakup beberapa hari ke depan.
  ///
  /// ⚠️ Begitu hari ini tuntas, pengingat HARI INI langsung dibatalkan —
  /// inilah yang membuat "hanya berbunyi kalau belum selesai" bisa bekerja
  /// walau notifikasi lokal tidak bisa memeriksa keadaan saat berbunyi.
  ///
  /// Ada penjagaan [sidik]: kalau keadaannya (tanggal, status tuntas, panjang
  /// runtutan) sama seperti pemasangan terakhir, fungsi ini langsung kembali.
  /// Tanpa itu, membuka halaman baca akan membatalkan & memasang ulang
  /// puluhan notifikasi tanpa alasan.
  Future<void> pastikanPengingatStreak() async {
    if (!NotificationService.isSupported) return;
    await NotificationService().init();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool aktif = prefs.getBool(_pengingatKey) ?? true;

    if (!aktif) {
      await NotificationService().batalPengingatStreak();
      await prefs.remove(_sidikPengingatKey);
      debugPrint('[Streak] Pengingat runtutan dimatikan user');
      return;
    }

    final RingkasanStreak data = await ringkasan();
    final bool dzikirTuntas = data.dzikirHariIniTuntas;
    final bool quranTuntas = data.progresQuran.cukup;

    final String sidik = [
      _formatTanggal(DateTime.now()),
      dzikirTuntas,
      quranTuntas,
      data.tertinggi,
    ].join('|');

    if (prefs.getString(_sidikPengingatKey) == sidik) return;

    await NotificationService().batalPengingatStreak();

    final List<PengingatStreak> rencana = rencanaPengingatStreak(
      hariIniTuntas: dzikirTuntas && quranTuntas,
      dzikirTuntas: dzikirTuntas,
      quranTuntas: quranTuntas,
      runtutanTertinggi: data.tertinggi,
    );

    final List<int> idTerpasang = <int>[];
    for (final PengingatStreak pengingat in rencana) {
      final bool berhasil = await NotificationService()
          .jadwalkanPengingatStreak(pengingat);
      if (berhasil) idTerpasang.add(pengingat.id);
    }

    await NotificationService().simpanIdPengingatStreak(idTerpasang);
    await prefs.setString(_sidikPengingatKey, sidik);

    debugPrint(
      '[Streak] ${idTerpasang.length} pengingat runtutan dipasang '
      '(dzikir: ${data.dzikir} hari, quran: ${data.quran} hari)',
    );
  }

  // =====================================================================
  // UTIL
  // =====================================================================

  static String _formatTanggal(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  static DateTime? _parseTanggal(String? teks) {
    if (teks == null || teks.isEmpty) return null;
    return DateTime.tryParse(teks);
  }
}

/// Progres baca Al-Qur'an hari ini.
class ProgresQuran {
  const ProgresQuran({required this.ayat, required this.halaman});

  final int ayat;
  final int halaman;

  /// Apakah salah satu mode sudah mencapai target.
  bool get cukup =>
      StreakService.quranSudahCukup(ayatHariIni: ayat, halamanHariIni: halaman);

  /// Ringkasan untuk ditampilkan, contoh: `7/10 ayat` atau `2/1 halaman`.
  String get teks {
    if (StreakService.ayatSudahCukup(ayat)) {
      return '$ayat/${StreakService.ayatMinimalTerjemahan} ayat';
    }
    if (StreakService.halamanSudahCukup(halaman)) {
      return '$halaman/${StreakService.halamanMinimalMushaf} halaman';
    }
    if (ayat > 0) return '$ayat/${StreakService.ayatMinimalTerjemahan} ayat';
    if (halaman > 0) {
      return '$halaman/${StreakService.halamanMinimalMushaf} halaman';
    }
    return 'belum dibaca';
  }
}

/// Ringkasan kedua runtutan untuk ditampilkan di UI.
class RingkasanStreak {
  const RingkasanStreak({
    required this.dzikir,
    required this.quran,
    required this.pagiTuntas,
    required this.soreTuntas,
    required this.dzikirHariIniTuntas,
    required this.progresQuran,
  });

  /// Panjang runtutan dzikir yang masih berlaku (0 = belum ada / sudah putus).
  final int dzikir;

  /// Panjang runtutan baca Al-Qur'an yang masih berlaku.
  final int quran;

  final bool pagiTuntas;
  final bool soreTuntas;

  /// Dzikir hari ini tuntas = pagi DAN sore.
  final bool dzikirHariIniTuntas;

  final ProgresQuran progresQuran;

  /// Runtutan terpanjang dari keduanya — dipakai untuk nada pengingat.
  int get tertinggi => dzikir > quran ? dzikir : quran;

  /// Apakah keduanya sudah tuntas hari ini.
  bool get semuaTuntasHariIni => dzikirHariIniTuntas && progresQuran.cukup;
}
