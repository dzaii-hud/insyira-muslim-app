/// Aturan WAKTU untuk dzikir pagi & petang.
///
/// Dzikir pagi dan petang masing-masing punya batas waktu. Setelah batasnya
/// lewat, dzikirnya **tidak dihitung lagi** — user masih bisa membacanya,
/// tetapi tombol counternya dimatikan dan kalau ditekan muncul pesan.
///
/// Ini keputusan pemilik aplikasi (1 Okt 2026): dzikir pagi sampai pukul
/// 11:00, dzikir petang sampai pukul 18:00.
///
/// ⚠️ Yang dibatasi hanya BATAS AKHIR, bukan waktu mulainya. Jadi secara
/// aturan, "dzikir petang" sudah dianggap terbuka sejak pukul 00:00 — user
/// sendiri yang memilih sesinya. Kalau nanti mau ada batas mulai (mis. petang
/// baru dibuka setelah Ashar), tambahkan di sini.
///
/// Sengaja berupa fungsi MURNI (tanpa akses perangkat) supaya bisa diuji
/// tanpa HP — lihat `test/dzikir_waktu_test.dart`.
class DzikirWaktu {
  DzikirWaktu._();

  /// Batas akhir dzikir PAGI (jam lokal perangkat).
  static const int jamBatasPagi = 11;

  /// Batas akhir dzikir PETANG (jam lokal perangkat).
  static const int jamBatasSore = 18;

  /// Pukul berapa sesi [isPagi] ditutup pada hari [pada].
  static DateTime batas({required bool isPagi, required DateTime pada}) =>
      DateTime(
        pada.year,
        pada.month,
        pada.day,
        isPagi ? jamBatasPagi : jamBatasSore,
      );

  /// Apakah sesi [isPagi] masih boleh dihitung pada waktu [sekarang].
  ///
  /// Batasnya EKSKLUSIF: tepat pukul 11:00 sudah dianggap lewat, karena
  /// "sampai jam 11" berarti berakhir saat jam 11 mulai.
  static bool masihDalamWaktu({required bool isPagi, DateTime? sekarang}) {
    final DateTime saat = sekarang ?? DateTime.now();
    return saat.isBefore(batas(isPagi: isPagi, pada: saat));
  }

  /// Label waktu siap tampil, mis. `11:00`.
  static String labelBatas({required bool isPagi}) =>
      '${(isPagi ? jamBatasPagi : jamBatasSore).toString().padLeft(2, '0')}:00';

  /// Nama sesi untuk ditampilkan di kalimat.
  static String namaSesi({required bool isPagi}) => isPagi ? 'pagi' : 'petang';

  /// Pesan yang muncul kalau user tetap menekan dzikir di luar waktunya.
  ///
  /// Bunyinya sengaja dipakai apa adanya seperti yang diminta pemilik
  /// aplikasi — jangan diubah tanpa diminta.
  static String pesanLewat({required bool isPagi}) =>
      'Afwan, waktu dzikir ${namaSesi(isPagi: isPagi)} sudah lewat, '
      'jangan lupa untuk berdzikir besok yaa';

  /// Keterangan singkat untuk banner di atas daftar dzikir.
  static String keteranganLewat({required bool isPagi}) =>
      'Waktu dzikir ${namaSesi(isPagi: isPagi)} sudah lewat '
      '(batas ${labelBatas(isPagi: isPagi)}). Hitungan dimatikan sampai besok.';

  /// Keterangan waktu yang masih berlaku, untuk ditampilkan di kartu sesi.
  static String keteranganBerlaku({required bool isPagi}) =>
      'Dzikir ${namaSesi(isPagi: isPagi)} · sampai ${labelBatas(isPagi: isPagi)}';
}
