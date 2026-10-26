import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Pemutar murottal **per ayat**.
///
/// ## Mengapa per ayat, bukan satu berkas per surah
///
/// Halaman baca Al-Qur'an di aplikasi ini bekerja per ayat (mode terjemahan)
/// dan per halaman (mode mushaf). Dengan audio per ayat, aplikasi bisa
/// menandai ayat mana yang sedang dibaca — sesuatu yang mustahil kalau
/// audionya satu berkas utuh per surah.
///
/// ## Mengapa bersambung otomatis
///
/// Per ayat tanpa penyambung berarti pembaca harus mengetuk 286 kali untuk
/// Al-Baqarah. Jadi begitu satu ayat selesai, ayat berikutnya langsung
/// diputar. Berhenti sendiri di akhir surah.
///
/// ## Sumber audio
///
/// Tautannya sudah ikut di dalam data surah yang dipakai halaman baca
/// (`ayat['audio']['05']`). Jadi tidak ada daftar tautan yang perlu dirawat
/// terpisah, dan tidak ada permintaan tambahan ke server.
///
/// Sengaja tidak mengunduh seluruh surah lebih dulu: audio dialirkan
/// (streaming), sehingga ukuran aplikasi tidak bertambah dan memori HP tetap
/// ringan.
class MurottalService {
  MurottalService._();

  static final MurottalService instance = MurottalService._();

  /// Kunci qari pada data API: 05 = Misyari Rasyid Al-Afasi.
  static const String kunciQari = '05';

  /// Nama qari untuk ditampilkan di layar.
  static const String namaQari = 'Misyari Rasyid Al-Afasi';

  final AudioPlayer _pemutar = AudioPlayer();
  StreamSubscription<void>? _langgananSelesai;

  /// Nomor ayat yang sedang diputar (`null` kalau tidak ada).
  final ValueNotifier<int?> sedangDiputar = ValueNotifier<int?>(null);

  /// Apakah audio sedang berbunyi (bukan sekadar sedang dimuat).
  final ValueNotifier<bool> berbunyi = ValueNotifier<bool>(false);

  int _nomorSurah = 0;
  List<dynamic> _daftarAyat = const <dynamic>[];
  int _indeks = 0;
  bool _disiapkan = false;

  bool get aktif => sedangDiputar.value != null;
  int get nomorSurah => _nomorSurah;

  Future<void> _siapkan() async {
    if (_disiapkan) return;
    _disiapkan = true;

    await _pemutar.setReleaseMode(ReleaseMode.stop);

    // Ayat selesai -> lanjut ayat berikutnya. Inilah yang membuat pemutaran
    // terasa seperti satu bacaan, bukan 286 ketukan.
    _langgananSelesai = _pemutar.onPlayerComplete.listen((_) {
      lanjut();
    });
  }

  /// Mulai memutar [daftarAyat] dari [nomorAyat].
  Future<void> mulai({
    required int nomorSurah,
    required List<dynamic> daftarAyat,
    int nomorAyat = 1,
  }) async {
    await _siapkan();

    _nomorSurah = nomorSurah;
    _daftarAyat = daftarAyat;

    if (_daftarAyat.isEmpty) return;

    await _putarIndeks((nomorAyat - 1).clamp(0, _daftarAyat.length - 1));
  }

  /// Memutar ayat ke-[indeks] (berbasis 0) pada daftar yang tersimpan.
  Future<void> putarIndeks(int indeks) => _putarIndeks(indeks);

  Future<void> _putarIndeks(int indeks) async {
    if (_daftarAyat.isEmpty) return;
    if (indeks < 0 || indeks >= _daftarAyat.length) return;

    _indeks = indeks;

    final dynamic mentah = _daftarAyat[indeks];
    final Map<String, dynamic> ayat = mentah is Map
        ? Map<String, dynamic>.from(mentah)
        : <String, dynamic>{};

    final String tautan = ((ayat['audio'] as Map?)?[kunciQari] ?? '')
        .toString();

    if (tautan.isEmpty) {
      // Data ayat ini tidak membawa audio. Lewati ke ayat berikutnya daripada
      // berhenti diam-diam di tengah bacaan.
      if (indeks + 1 < _daftarAyat.length) {
        await _putarIndeks(indeks + 1);
      }
      return;
    }

    sedangDiputar.value = (ayat['nomorAyat'] as num?)?.toInt() ?? (indeks + 1);
    berbunyi.value = true;

    await _pemutar.play(UrlSource(tautan));
  }

  Future<void> jeda() async {
    await _pemutar.pause();
    berbunyi.value = false;
  }

  Future<void> lanjutkan() async {
    if (!aktif) return;

    await _pemutar.resume();
    berbunyi.value = true;
  }

  /// Ayat berikutnya, atau berhenti kalau sudah di ayat terakhir.
  Future<void> lanjut() async {
    if (_indeks + 1 >= _daftarAyat.length) {
      await berhenti();
      return;
    }

    await _putarIndeks(_indeks + 1);
  }

  Future<void> sebelumnya() async {
    if (_indeks <= 0) return;

    await _putarIndeks(_indeks - 1);
  }

  Future<void> berhenti() async {
    await _pemutar.stop();
    sedangDiputar.value = null;
    berbunyi.value = false;
  }

  /// Melepas pemutar. Dipanggil saat aplikasi benar-benar ditutup.
  Future<void> tutup() async {
    await _langgananSelesai?.cancel();
    await _pemutar.dispose();
  }
}
