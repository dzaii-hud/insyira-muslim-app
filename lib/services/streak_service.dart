import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dzikir_service.dart';
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

  // --- Prefs: riwayat tanggal yang pernah tuntas ---
  //
  // Sengaja menyimpan DAFTAR TANGGAL, bukan cuma jumlah runtutan: kartu
  // bulatan per-hari di halaman Quran & Dzikir perlu tahu hari mana saja yang
  // sudah tuntas, dan itu tidak bisa dihitung dari panjang runtutan sekarang
  // (mis. runtutan 5 hari tapi bolong 2 hari di tengah).
  static const String _riwayatDzikirKey = 'streak_dzikir_riwayat';
  static const String _riwayatQuranKey = 'streak_quran_riwayat';

  /// Prefs: hari yang cuma selesai SATU dzikir (pagi saja atau petang saja).
  ///
  /// Harinya TETAP dihitung sebagai runtutan (lihat `_perbaruiRuntutanDzikir`)
  /// — penanda ini hanya untuk tampilan: bulatannya digambar setengah kuning
  /// setengah biru, supaya jelas bahwa sesi yang lain terlewat.
  static const String _riwayatSebagianKey = 'streak_dzikir_riwayat_sebagian';

  /// Berapa tanggal terakhir yang disimpan. Cukup untuk beberapa minggu ke
  /// belakang, tapi tidak tumbuh tanpa batas.
  static const int batasRiwayat = 28;

  /// Label hari, Senin sampai Minggu — dipakai kartu bulatan per-hari.
  static const List<String> labelHari = <String>[
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

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

  /// Menyusun tujuh hari dalam MINGGU BERJALAN (Senin–Minggu) untuk kartu
  /// bulatan per-hari.
  ///
  /// Memakai minggu kalender, bukan "7 hari terakhir", supaya posisinya tetap
  /// dan mudah dibaca: hari yang sama selalu ada di kolom yang sama.
  /// [tanggalTuntas] berisi tanggal berformat `yyyy-MM-dd`.
  /// [tanggalSebagian] berisi hari yang cuma selesai sebagian (dzikir: baru
  /// satu sesi) — harinya tetap dihitung runtutan, tapi bulatannya setengah.
  ///
  /// Fungsi murni — bisa diuji tanpa HP.
  static List<HariStreak> mingguIni({
    required DateTime sekarang,
    required Set<String> tanggalTuntas,
    Set<String>? tanggalSebagian,
  }) {
    final DateTime hariIni = hari(sekarang);

    // DateTime.weekday: 1 = Senin ... 7 = Minggu.
    final DateTime senin = hariIni.subtract(
      Duration(days: hariIni.weekday - 1),
    );

    return <HariStreak>[
      for (int i = 0; i < 7; i++)
        _hariKe(
          senin: senin,
          i: i,
          hariIni: hariIni,
          tuntas: tanggalTuntas,
          sebagian: tanggalSebagian ?? const <String>{},
        ),
    ];
  }

  static HariStreak _hariKe({
    required DateTime senin,
    required int i,
    required DateTime hariIni,
    required Set<String> tuntas,
    required Set<String> sebagian,
  }) {
    final DateTime tanggal = senin.add(Duration(days: i));
    final String kunci = _formatTanggal(tanggal);
    final bool adasebagian = sebagian.contains(kunci);

    // Hari yang ada di daftar "sebagian" TIDAK boleh dianggap penuh walau
    // tanggalnya juga tercatat di daftar tuntas: daftar tuntas memuat SEMUA
    // hari yang dihitung sebagai runtutan, termasuk yang cuma satu sesi.
    final bool penuh = tuntas.contains(kunci) && !adasebagian;

    return HariStreak(
      tanggal: tanggal,
      label: labelHari[i],
      tuntas: penuh,
      sebagian: !penuh && adasebagian,
      hariIni: tanggal == hariIni,
      masaDepan: tanggal.isAfter(hariIni),
    );
  }

  /// Menyusun daftar pengingat penyelamat runtutan untuk beberapa hari ke depan.
  ///
  /// Hanya dipasang pada jam [NotificationService.jamPengingatStreak], dan
  /// HARI INI dilewati kalau [kekurangan] kosong — supaya tidak ada pengingat
  /// yang berbunyi untuk pekerjaan yang sudah selesai.
  ///
  /// ⚠️ [kekurangan] HARUS berisi hal yang memang MASIH BISA DIKEJAR saat
  /// pengingatnya berbunyi. Dzikir pagi misalnya sudah mustahil dikerjakan
  /// kalau pengingatnya baru muncul sore hari, jadi jangan dimasukkan —
  /// menagih sesuatu yang tidak mungkin hanya membuat notifikasinya terasa
  /// salah. Penyaringan itu dilakukan pemanggilnya (lihat
  /// `pastikanPengingatStreak`), karena butuh tahu jam pengingatnya.
  ///
  /// Fungsi murni: tidak menyentuh plugin notifikasi.
  static List<PengingatStreak> rencanaPengingatStreak({
    required Set<BagianRuntutan> kekurangan,
    required int runtutanTertinggi,
    DateTime? sekarang,
    int hariKeDepan = NotificationService.hariPengingatStreakKeDepan,
  }) {
    final saat = sekarang ?? DateTime.now();
    final rencana = <PengingatStreak>[];

    for (int h = 0; h < hariKeDepan; h++) {
      // Hari ini tidak perlu dijadwalkan kalau tidak ada lagi yang bisa
      // dikejar.
      if (h == 0 && kekurangan.isEmpty) continue;

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
          // Untuk hari-hari berikutnya kekurangannya belum bisa diketahui,
          // jadi memakai pesan umum.
          isi: h == 0
              ? _isiPengingatStreak(
                  kekurangan: kekurangan,
                  runtutanTertinggi: runtutanTertinggi,
                )
              : _isiPengingatUmum(runtutanTertinggi: runtutanTertinggi),
        ),
      );
    }

    return rencana;
  }

  /// Isi notifikasi HARI INI, menyebut apa saja yang masih kurang.
  static String _isiPengingatStreak({
    required Set<BagianRuntutan> kekurangan,
    required int runtutanTertinggi,
  }) {
    if (kekurangan.isEmpty) {
      return 'Alhamdulillah, semua sudah tuntas hari ini. 🌙';
    }

    // Diurutkan mengikuti urutan enum supaya kalimatnya tidak berubah-ubah
    // urutannya antar pemanggilan.
    final List<BagianRuntutan> urut = kekurangan.toList()
      ..sort(
        (BagianRuntutan a, BagianRuntutan b) => a.index.compareTo(b.index),
      );

    final pembuka = runtutanTertinggi > 0
        ? 'Runtutan $runtutanTertinggi hari bisa putus kalau hari ini terlewat. '
        : 'Belum ada runtutan hari ini. ';

    return '${pembuka}Tinggal '
        '${urut.map((BagianRuntutan b) => b.keterangan).join(' dan ')}.';
  }

  /// Isi notifikasi untuk hari-hari BERIKUTNYA (kekurangannya belum diketahui).
  static String _isiPengingatUmum({required int runtutanTertinggi}) {
    if (runtutanTertinggi > 0) {
      return 'Runtutan $runtutanTertinggi hari bisa putus kalau hari ini '
          'terlewat. Lengkapi dzikir pagi & petang serta baca Al-Qur\'an.';
    }
    return 'Mulai runtutan hari ini: dzikir pagi & petang serta baca '
        'Al-Qur\'an.';
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

  /// Apakah SUDAH ADA minimal satu dzikir yang tuntas hari ini.
  ///
  /// Inilah syarat runtutan dzikir — bukan harus pagi + sore.
  Future<bool> adaDzikirHariIni() async {
    final prefs = await SharedPreferences.getInstance();
    final hariIni = _formatTanggal(DateTime.now());
    return prefs.getString(_dzikirPagiKey) == hariIni ||
        prefs.getString(_dzikirSoreKey) == hariIni;
  }

  /// Menambah runtutan dzikir untuk hari ini.
  ///
  /// ⚠️ Cukup SALAH SATU sesi (pagi ATAU petang) — bukan harus keduanya.
  /// Alasannya: tiap sesi punya batas waktu sendiri, jadi user yang
  /// menyelesaikan dzikir pagi lalu kehabisan waktu untuk petang tidak boleh
  /// kehilangan runtutannya. Hari yang cuma satu sesi ditandai "sebagian"
  /// supaya bulatannya digambar setengah.
  Future<void> _perbaruiRuntutanDzikir() async {
    if (!await adaDzikirHariIni()) return;

    final prefs = await SharedPreferences.getInstance();
    await _catatRuntutan(
      prefs: prefs,
      kunciJumlah: _runtutanDzikirKey,
      kunciTerakhir: _runtutanDzikirTerakhirKey,
      kunciRiwayat: _riwayatDzikirKey,
    );

    // Kalau ternyata sekarang sudah lengkap, tanda "sebagian"-nya DIHAPUS —
    // jadi bulatannya berubah jadi penuh tanpa perlu campur tangan user.
    await _perbaruiRiwayatSebagian(
      prefs,
      sebagian: !await dzikirHariIniTuntas(),
    );
  }

  /// Menambah/menghapus tanggal hari ini dari daftar "sebagian".
  Future<void> _perbaruiRiwayatSebagian(
    SharedPreferences prefs, {
    required bool sebagian,
  }) async {
    final String hariIni = _formatTanggal(DateTime.now());
    final List<String> daftar = _bacaRiwayat(
      prefs.getString(_riwayatSebagianKey),
    );
    final bool sudahAda = daftar.contains(hariIni);

    if (sebagian == sudahAda) return;

    if (sebagian) {
      daftar.add(hariIni);
    } else {
      daftar.remove(hariIni);
    }

    await prefs.setString(
      _riwayatSebagianKey,
      jsonEncode(_pangkasRiwayat(daftar)),
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
        kunciRiwayat: _riwayatQuranKey,
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
    required String kunciRiwayat,
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

    // Riwayat tanggalnya ditambah SEKALI saja per hari (dicek dulu, karena
    // fungsi ini bisa terpanggil berkali-kali dalam sehari).
    final List<String> riwayat = _bacaRiwayat(prefs.getString(kunciRiwayat));
    final String hariIni = _formatTanggal(sekarang);
    if (!riwayat.contains(hariIni)) {
      riwayat.add(hariIni);
      await prefs.setString(kunciRiwayat, jsonEncode(_pangkasRiwayat(riwayat)));
    }
  }

  /// Membaca riwayat tanggal dari prefs. Tahan terhadap data rusak.
  static List<String> _bacaRiwayat(String? mentah) {
    if (mentah == null || mentah.isEmpty) return <String>[];
    try {
      return (jsonDecode(mentah) as List<dynamic>)
          .map((dynamic e) => e.toString())
          .toList();
    } catch (e) {
      debugPrint('[Streak] Gagal membaca riwayat: $e');
      return <String>[];
    }
  }

  /// Menyisakan [batasRiwayat] tanggal TERAKHIR, tetap urut lama → baru.
  static List<String> _pangkasRiwayat(List<String> riwayat) {
    final List<String> urut = List<String>.from(riwayat)..sort();
    if (urut.length <= batasRiwayat) return urut;
    return urut.sublist(urut.length - batasRiwayat);
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
      tanggalDzikir: _bacaRiwayat(prefs.getString(_riwayatDzikirKey)).toSet(),
      tanggalQuran: _bacaRiwayat(prefs.getString(_riwayatQuranKey)).toSet(),
      tanggalDzikirSebagian: _bacaRiwayat(
        prefs.getString(_riwayatSebagianKey),
      ).toSet(),
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

    // Yang ditagih HANYA yang masih bisa dikerjakan saat pengingatnya
    // berbunyi. Dzikir pagi tutup pukul 11:00, sedangkan pengingat runtutan
    // berbunyi lebih sore dari itu — menagih dzikir pagi di sore hari hanya
    // membuat notifikasinya terasa salah.
    final DateTime waktuPengingat = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      NotificationService.jamPengingatStreak,
    );

    final Set<BagianRuntutan> kekurangan = <BagianRuntutan>{
      if (!data.pagiTuntas &&
          DzikirWaktu.masihDalamWaktu(isPagi: true, sekarang: waktuPengingat))
        BagianRuntutan.dzikirPagi,
      if (!data.soreTuntas &&
          DzikirWaktu.masihDalamWaktu(isPagi: false, sekarang: waktuPengingat))
        BagianRuntutan.dzikirPetang,
      if (!data.progresQuran.cukup) BagianRuntutan.quran,
    };

    final String sidik = [
      _formatTanggal(DateTime.now()),
      data.tertinggi,
      kekurangan.map((BagianRuntutan b) => b.name).join(','),
    ].join('|');

    if (prefs.getString(_sidikPengingatKey) == sidik) return;

    await NotificationService().batalPengingatStreak();

    final List<PengingatStreak> rencana = rencanaPengingatStreak(
      kekurangan: kekurangan,
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
    this.tanggalDzikir = const <String>{},
    this.tanggalQuran = const <String>{},
    this.tanggalDzikirSebagian = const <String>{},
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

  /// Tanggal (format `yyyy-MM-dd`) yang pernah tuntas, untuk kartu bulatan
  /// per-hari di halaman Quran & Dzikir.
  final Set<String> tanggalDzikir;
  final Set<String> tanggalQuran;

  /// Tanggal yang cuma selesai SATU dzikir (pagi saja atau petang saja).
  /// Harinya tetap dihitung sebagai runtutan, tapi bulatannya setengah.
  final Set<String> tanggalDzikirSebagian;

  /// Runtutan terpanjang dari keduanya — dipakai untuk nada pengingat.
  int get tertinggi => dzikir > quran ? dzikir : quran;

  /// Apakah keduanya sudah tuntas hari ini.
  bool get semuaTuntasHariIni => dzikirHariIniTuntas && progresQuran.cukup;
}

/// Satu hari di dalam kartu bulatan per-hari.
///
class HariStreak {
  const HariStreak({
    required this.tanggal,
    required this.label,
    required this.tuntas,
    required this.sebagian,
    required this.hariIni,
    required this.masaDepan,
  });

  final DateTime tanggal;

  /// Label pendek hari, mis. `Sen`.
  final String label;

  /// Hari ini tuntas PENUH (untuk dzikir: pagi dan petang dua-duanya).
  final bool tuntas;

  /// Hari ini cuma tuntas SEBAGIAN (untuk dzikir: baru satu sesi).
  /// Digambar setengah kuning setengah biru.
  final bool sebagian;

  final bool hariIni;

  /// Hari ini belum terjadi (masih di depan dalam minggu ini).
  final bool masaDepan;
}

/// Bagian runtutan yang bisa masih kurang pada suatu hari.
///
/// Dipakai pengingat penyelamat runtutan untuk menyebut APA yang masih
/// tertinggal, bukan cuma "belum tuntas".
///
/// ⚠️ [keterangan] ikut menentukan bunyi notifikasi — jangan diubah tanpa
/// memeriksa `test/streak_test.dart`.
enum BagianRuntutan {
  dzikirPagi('dzikir pagi'),
  dzikirPetang('dzikir petang'),
  quran(
    '${StreakService.ayatMinimalTerjemahan} ayat atau '
    '${StreakService.halamanMinimalMushaf} halaman',
  );

  const BagianRuntutan(this.keterangan);

  /// Sebutan bagian ini di dalam kalimat notifikasi.
  final String keterangan;
}
