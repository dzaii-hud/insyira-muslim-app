/// Identitas aplikasi Insyira Muslim App.
///
/// Semua tempat yang menampilkan nama, versi, atau tautan resmi aplikasi
/// (halaman Tentang, Pengaturan, sidebar) membaca dari sini supaya tidak ada
/// dua tempat yang isinya bisa berbeda.
///
/// ⚠️ [versi] dan [nomorBuild] WAJIB sama dengan `version:` di `pubspec.yaml`.
/// Kebenarannya dijaga otomatis oleh `test/app_info_test.dart` — kalau pubspec
/// dinaikkan tapi berkas ini lupa diperbarui, tesnya akan gagal.
class AppInfo {
  AppInfo._();

  // =====================================================================
  // NAMA & VERSI
  // =====================================================================

  /// Nama lengkap aplikasi, sama dengan yang tertulis di Play Store.
  static const String nama = 'Insyira Muslim App';

  /// Nama pendek — dipakai di sidebar dan AppBar supaya tidak panjang.
  static const String namaPendek = 'Insyira';

  /// Versi rilis, yaitu bagian SEBELUM tanda `+` pada `version:` di pubspec.
  static const String versi = '1.0.0';

  /// Nomor build, yaitu bagian SESUDAH tanda `+` pada `version:` di pubspec.
  /// Angka ini yang dibaca Google Play sebagai `versionCode`.
  static const String nomorBuild = '8';

  /// Teks versi siap tampil, mis. `1.0.0 (build 6)`.
  static const String versiLengkap = '$versi (build $nomorBuild)';

  /// Pengembang yang terdaftar di Play Store.
  static const String pengembang = 'Insyira Pekanbaru';

  /// Kalimat singkat tentang isi aplikasi.
  static const String deskripsi =
      'Panduan ibadah sehari-hari untuk umat Muslim: jadwal sholat beserta '
      'adzan, Al-Quran, arah kiblat, dzikir pagi dan sore, serta jadwal kajian '
      'dan fawaidh asatidz.';

  // =====================================================================
  // TAUTAN RESMI
  // =====================================================================

  // ⚠️ PERHATIKAN EJAANNYA — dua domain di bawah memang BEDA dan keduanya
  // sengaja dipakai apa adanya. Jangan "diperbaiki" jadi sama:
  //
  //   * situs          -> pusatolEOLahpekanbaru.id   (ejaan asli pendaftaran)
  //   * surel/email    -> pusatolEHOLahpekanbaru.id  (ejaan yang didaftarkan
  //                        sebagai kontak di Play Console)
  //
  // Keduanya sudah diverifikasi aktif, jadi ubah hanya kalau memang pindah
  // alamat.

  /// Situs resmi aplikasi (versi web aplikasi ini).
  static const String situs =
      'https://insyiramuslimapp.pusatoleolehpekanbaru.id';

  /// Kebijakan privasi — berkas statis di server backend.
  static const String kebijakanPrivasi =
      'https://api.pusatoleolehpekanbaru.id/privacy.html';

  /// Penjelasan cara menghapus akun.
  static const String hapusAkun =
      'https://api.pusatoleolehpekanbaru.id/hapus-akun.html';

  /// Surel resmi pengembang.
  static const String email = 'contact@pusatoleholehpekanbaru.id';

  /// Kanal YouTube "Insyira TV" — sumber video pada bagian Kajian Online.
  static const String kanalYouTube =
      'https://www.youtube.com/channel/UCxYY8T_y2mAgQQCjYvWwZdw';
}
