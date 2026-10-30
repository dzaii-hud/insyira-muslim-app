import '../app_info.dart';
import 'notification_service.dart';
import 'streak_service.dart';
import 'tips_sira.dart';

/// Balasan Sira untuk satu pertanyaan.
class BalasanSira {
  const BalasanSira({required this.teks, this.saran = const <String>[]});

  /// Isi jawaban. Boleh beberapa kalimat, dipisah baris baru.
  final String teks;

  /// Pertanyaan lanjutan yang bisa diketuk pengguna.
  final List<String> saran;
}

/// Hal-hal yang diketahui Sira saat menjawab.
///
/// [halaman] diisi dari [SiraPendamping], jadi jawaban Sira selalu mengacu ke
/// halaman yang benar-benar sedang dibuka — bukan tebakan dari pertanyaan.
class KonteksSira {
  const KonteksSira({required this.halaman, this.tabHome = 0, this.jam});

  final String halaman;
  final int tabHome;

  /// Jam "sekarang". Bisa diisi di tes supaya jawaban tidak berubah-ubah.
  final DateTime? jam;

  DateTime get sekarang => jam ?? DateTime.now();

  /// Nama halaman siap pakai, mis. "Pengaturan" atau "Beranda".
  ///
  /// Dipakai di kalimat Sira ("kamu sedang di …"), jadi bentuknya harus enak
  /// dibaca — bukan judul tips yang kadang berupa kalimat ajakan.
  String get judulHalaman {
    if (halaman == HalamanSira.home) {
      const List<String> namaTab = <String>[
        'Beranda',
        'Al-Qur\'an',
        'Arah Kiblat',
        'Jadwal Kajian',
        'Dzikir',
      ];
      return namaTab[tabHome.clamp(0, namaTab.length - 1)];
    }

    const Map<String, String> nama = <String, String>{
      HalamanSira.pengaturan: 'Pengaturan',
      HalamanSira.tentang: 'Tentang Aplikasi',
      HalamanSira.tonton: 'Pemutar Video',
      HalamanSira.fawaidh: 'Fawaidh',
      HalamanSira.fawaidhBaca: 'Membaca Fawaidh',
      HalamanSira.fawaidhSaya: 'Fawaidh Saya',
    };
    return nama[halaman] ?? 'Insyira';
  }
}

/// Sumber jadwal sholat hari ini (nama waktu -> waktu).
typedef PenyediaJadwalSholat = Future<Map<String, DateTime>> Function();

/// Sumber runtutan pengguna.
typedef PenyediaRuntutan = Future<RingkasanStreak?> Function();

/// "Otak" obrolan Sira.
///
/// Sengaja tanpa jaringan dan tanpa model bahasa: seluruh jawaban disusun dari
/// pengetahuan tentang aplikasi ini plus data yang sudah ada di HP (jadwal
/// sholat, runtutan). Akibatnya obrolan tetap jalan tanpa internet, tidak
/// mengirim data pengguna ke mana pun, dan tidak butuh server baru.
///
/// Data dari luar disuntikkan lewat [PenyediaJadwalSholat] dan
/// [PenyediaRuntutan] supaya bisa diuji tanpa membangun pohon widget.
class SiraObrolan {
  SiraObrolan({
    PenyediaJadwalSholat? jadwalSholat,
    PenyediaRuntutan? runtutan,
  }) : _jadwalSholat = jadwalSholat ?? _jadwalBawaan,
       _runtutan = runtutan ?? _runtutanBawaan;

  /// Satu-satunya contoh yang dipakai aplikasi.
  static final SiraObrolan bawaan = SiraObrolan();

  final PenyediaJadwalSholat _jadwalSholat;
  final PenyediaRuntutan _runtutan;

  static Future<Map<String, DateTime>> _jadwalBawaan() =>
      NotificationService().getSavedPrayerTimes();

  static Future<RingkasanStreak?> _runtutanBawaan() async {
    try {
      return await StreakService().ringkasan();
    } catch (_) {
      // Obrolan tidak boleh mati hanya karena data runtutan belum ada.
      return null;
    }
  }

  /// Menjawab satu pertanyaan.
  Future<BalasanSira> jawab(
    String pertanyaan, {
    required KonteksSira konteks,
  }) async {
    final String tanya = _rapikan(pertanyaan);
    if (tanya.isEmpty) return _sapa('', konteks);

    final String? topik = _pilihTopik(tanya);

    switch (topik) {
      case 'halaman':
        return _jawabHalaman(konteks);
      case 'sholat':
        return _jawabSholat(tanya, konteks);
      case 'adzan':
        return _jawabAdzan();
      case 'dzikir':
        return _jawabDzikir(konteks);
      case 'runtutan':
        return _jawabRuntutan();
      case 'quran':
        return _jawabQuran();
      case 'kiblat':
        return _jawabKiblat();
      case 'kajian':
        return _jawabKajian();
      case 'fawaidh':
        return _jawabFawaidh();
      case 'video':
        return _jawabVideo();
      case 'pengaturan':
        return _jawabPengaturan();
      case 'akun':
        return _jawabAkun();
      case 'tentang':
        return _jawabTentang();
      case 'sira':
        return _jawabSira(konteks);
      case 'kontak':
        return _jawabKontak();
      case 'terimakasih':
        return _jawabTerimaKasih(konteks);
      case 'sapa':
        return _sapa(tanya, konteks);
      default:
        return _jawabTidakPaham(konteks);
    }
  }

  /// Saran pertanyaan untuk halaman yang sedang dibuka.
  ///
  /// Dipakai sebagai tombol cepat di awal obrolan, supaya pengguna tidak
  /// kebingungan harus mengetik apa.
  List<String> saranUntuk(KonteksSira konteks) {
    switch (konteks.halaman) {
      case HalamanSira.pengaturan:
        return <String>[
          'Kenapa adzan tidak berbunyi?',
          'Cara mematikan Sira',
          'Apa itu widget layar utama?',
        ];
      case HalamanSira.tentang:
        return <String>['Versi aplikasi apa?', 'Cara menghubungi pengurus'];
      case HalamanSira.tonton:
        return <String>[
          'Kenapa video tidak muncul?',
          'Cara menonton siaran langsung',
        ];
      case HalamanSira.fawaidh:
      case HalamanSira.fawaidhBaca:
        return <String>['Apa itu fawaidh?', 'Cara membaca Al-Qur\'an'];
      case HalamanSira.fawaidhSaya:
        return <String>['Siapa yang bisa menulis fawaidh?', 'Apa itu fawaidh?'];
      case HalamanSira.home:
        if (konteks.tabHome == 1) {
          return <String>['Cara baca Al-Qur\'an', 'Apa itu runtutan?'];
        }
        if (konteks.tabHome == 2) {
          return <String>['Cara memakai kompas kiblat', 'Kenapa jarum bergerak?'];
        }
        if (konteks.tabHome == 3) {
          return <String>['Kajian terbaru kapan?', 'Cara menonton kajian live'];
        }
        if (konteks.tabHome == 4) {
          return <String>['Batas waktu dzikir pagi', 'Apa itu runtutan?'];
        }
        return <String>[
          'Jadwal sholat hari ini',
          'Apa itu runtutan?',
          'Cara baca Al-Qur\'an',
        ];
      default:
        return <String>['Apa itu Insyira?', 'Cara menghubungi pengurus'];
    }
  }

  // =====================================================================
  // PEMILIHAN TOPIK
  // =====================================================================
  String? _pilihTopik(String t) {
    // Pertanyaan yang menyebut halaman ("di sini", "halaman ini") selalu
    // dijawab dengan halaman yang sedang terbuka.
    if (_kataAda(t, 'halaman') || _adaFrasa(t, 'di sini')) {
      if (_kataAda(t, 'apa') ||
          _kataAda(t, 'ini') ||
          _kataAda(t, 'mana') ||
          _kataAda(t, 'bisa') ||
          _kataAda(t, 'gimana') ||
          _kataAda(t, 'bagaimana')) {
        return 'halaman';
      }
    }

    String? terpilih;
    int terbaik = 0;
    for (final _Topik topik in _daftarTopik) {
      final int skor = _skor(t, topik.kunci);
      if (skor > terbaik) {
        terbaik = skor;
        terpilih = topik.nama;
      }
    }

    // "assalamualaikum sira" hanya menyebut nama Sira — itu sapaan, bukan
    // pertanyaan tentang Sira.
    if (terbaik <= 2 && _skor(t, _kunciSapa) > 0) return 'sapa';

    return terbaik >= 2 ? terpilih : null;
  }

  static const List<_Topik> _daftarTopik = <_Topik>[
    _Topik('sholat', <String>[
      'sholat',
      'salat',
      'subuh',
      'dzuhur',
      'ashar',
      'maghrib',
      'isya',
      'waktu sholat',
      'jam berapa',
    ]),
    _Topik('adzan', <String>[
      'adzan',
      'azan',
      'bunyi',
      'berbunyi',
      'suara',
      'notifikasi',
      'alarm',
      'penghemat',
      'baterai',
      'izin',
    ]),
    _Topik('dzikir', <String>['dzikir', 'wirid', 'pagi dan sore', 'dzikir sore']),
    _Topik('runtutan', <String>[
      'runtutan',
      'streak',
      'runtun',
      'konsisten',
      'target',
      'progres',
    ]),
    _Topik('quran', <String>[
      'quran',
      'surah',
      'baca',
      'membaca',
      'mushaf',
      'terjemah',
      'murottal',
      'ayat',
      'ngaji',
    ]),
    _Topik('kiblat', <String>['kiblat', 'kompas', 'arah', 'jarum', 'utara']),
    _Topik('kajian', <String>[
      'kajian',
      'ustadz',
      'ustaz',
      'jadwal kajian',
      'live',
      'siaran',
    ]),
    _Topik('fawaidh', <String>['fawaidh', 'faedah', 'tulisan', 'artikel']),
    _Topik('video', <String>['video', 'youtube', 'nonton', 'pemutar', 'layar penuh']),
    _Topik('pengaturan', <String>[
      'pengaturan',
      'setting',
      'tema',
      'gelap',
      'terang',
      'widget',
      'ukuran huruf',
    ]),
    _Topik('akun', <String>[
      'akun',
      'login',
      'masuk',
      'daftar',
      'tamu',
      'kata sandi',
      'password',
      'google',
      'hapus akun',
    ]),
    _Topik('tentang', <String>[
      'tentang',
      'versi',
      'build',
      'insyira',
      'aplikasi',
    ]),
    _Topik('sira', <String>['sira', 'kamu siapa', 'maskot', 'lentera']),
    _Topik('kontak', <String>[
      'kontak',
      'hubungi',
      'menghubungi',
      'admin',
      'pengurus',
      'email',
      'lapor',
      'masalah',
    ]),
    _Topik('terimakasih', <String>['makasih', 'terima kasih', 'syukron', 'jazak']),
    _Topik('sapa', _kunciSapa),
  ];

  static const List<String> _kunciSapa = <String>[
    'halo',
    'hai',
    'assalamualaikum',
    'salam',
    'selamat pagi',
    'selamat siang',
    'selamat malam',
  ];

  // =====================================================================
  // JAWABAN
  // =====================================================================
  BalasanSira _sapa(String tanya, KonteksSira konteks) {
    final String salam = tanya.contains('assalamualaikum')
        ? 'Wa\'alaikumussalam! '
        : 'Halo! ';
    return BalasanSira(
      teks:
          '${salam}Aku Sira. Sekarang kamu di halaman '
          '${konteks.judulHalaman}.\n\nTanya apa saja soal aplikasi ini, ya.',
      saran: saranUntuk(konteks),
    );
  }

  BalasanSira _jawabHalaman(KonteksSira konteks) {
    final TipsSira? tips = cariTipsSira(
      namaHalaman: konteks.halaman,
      tab: konteks.tabHome,
    );

    if (tips == null) {
      return BalasanSira(
        teks:
            'Kamu sedang di halaman ${konteks.judulHalaman}. Di halaman ini aku '
            'tidak punya catatan khusus, tapi tanya apa saja soal Insyira — '
            'aku bantu jelaskan.',
        saran: saranUntuk(konteks),
      );
    }

    final List<String> poin = tips.poin.take(2).toList();
    return BalasanSira(
      teks:
          'Kamu sedang di halaman ${tips.judul}.\n\n'
          '${poin.map((String p) => '• $p').join('\n')}',
      saran: saranUntuk(konteks),
    );
  }

  Future<BalasanSira> _jawabSholat(
    String tanya,
    KonteksSira konteks,
  ) async {
    final Map<String, DateTime> jadwal = await _jadwalSholat();
    final DateTime sekarang = konteks.sekarang;

    if (jadwal.isEmpty || !_jadwalUntukHariIni(jadwal, sekarang)) {
      return const BalasanSira(
        teks:
            'Jadwal sholat belum tersedia di HP ini. Buka Beranda sebentar dan '
            'izinkan akses lokasi — jadwalnya dihitung otomatis dari posisimu, '
            'lalu aku bisa memberitahu waktu sholat berikutnya.',
        saran: <String>['Kenapa adzan tidak berbunyi?', 'Cara memakai kompas kiblat'],
      );
    }

    for (final String nama in _urutanSholat) {
      if (!_kataAda(tanya, nama.toLowerCase())) continue;
      final DateTime? waktu = jadwal[nama];
      if (waktu == null) continue;
      return BalasanSira(
        teks: 'Sholat $nama hari ini pukul ${_jam(waktu)}.',
        saran: <String>['Jadwal sholat hari ini', 'Kenapa adzan tidak berbunyi?'],
      );
    }

    String? namaBerikut;
    DateTime? waktuBerikut;
    for (final String nama in _urutanSholat) {
      final DateTime? waktu = jadwal[nama];
      if (waktu == null) continue;
      if (waktu.isAfter(sekarang)) {
        namaBerikut = nama;
        waktuBerikut = waktu;
        break;
      }
    }

    if (namaBerikut == null || waktuBerikut == null) {
      return BalasanSira(
        teks:
            'Semua waktu sholat hari ini sudah lewat. Yang terakhir: Isya pukul '
            '${_jam(jadwal['Isya'] ?? sekarang)}.\n\n'
            'Besok jadwalnya diperbarui otomatis saat kamu membuka Beranda.',
        saran: const <String>['Apa itu runtutan?', 'Cara baca Al-Qur\'an'],
      );
    }

    final Duration sisa = waktuBerikut.difference(sekarang);
    return BalasanSira(
      teks:
          'Sekarang pukul ${_jam(sekarang)}. Sholat berikutnya '
          '${namaBerikut.toLowerCase()} pukul ${_jam(waktuBerikut)}, sekitar '
          '${_durasi(sisa)} lagi.',
      saran: <String>['Kenapa adzan tidak berbunyi?', 'Cara memakai kompas kiblat'],
    );
  }

  BalasanSira _jawabAdzan() {
    return const BalasanSira(
      teks:
          'Kalau adzan tidak berbunyi, periksa tiga hal ini:\n'
          '• Izin notifikasi aplikasi: buka Pengaturan → Status Notifikasi.\n'
          '• Penghemat baterai: HP sering memblokir suara saat penghemat aktif. '
          'Kecualikan Insyira dari penghemat.\n'
          '• Volume & mode senyap: coba tombol "Tes Notifikasi Adzan" di '
          'Pengaturan.',
      saran: <String>['Jadwal sholat hari ini', 'Cara mematikan Sira'],
    );
  }

  BalasanSira _jawabDzikir(KonteksSira konteks) {
    return const BalasanSira(
      teks:
          'Dzikir pagi bisa dikerjakan sampai pukul 11.00, dzikir sore sampai '
          'pukul 18.00.\n\nKalau waktunya sudah lewat, sesi itu ditandai '
          'terlewat — bukan "belum" — karena memang sudah tidak bisa '
          'dikerjakan. Audionya ada di tiap dzikir.',
      saran: <String>['Apa itu runtutan?', 'Jadwal sholat hari ini'],
    );
  }

  Future<BalasanSira> _jawabRuntutan() async {
    final RingkasanStreak? r = await _runtutan();
    if (r == null) {
      return const BalasanSira(
        teks:
            'Runtutan dihitung dari dzikir dan bacaan Al-Qur\'anmu. Selesaikan '
            'dzikir pagi & sore, lalu baca minimal 10 ayat atau 1 halaman '
            'mushaf untuk menambah runtutan hari itu. Runtutan putus kalau '
            'bolong lebih dari 3 hari.',
        saran: <String>['Cara baca Al-Qur\'an', 'Batas waktu dzikir pagi'],
      );
    }

    final String dzikirHariIni = r.dzikirHariIniTuntas
        ? 'sudah tuntas'
        : 'pagi ${r.pagiTuntas ? 'selesai' : 'belum'}, '
              'sore ${r.soreTuntas ? 'selesai' : 'belum'}';

    return BalasanSira(
      teks:
          'Runtutanmu: dzikir ${r.dzikir} hari, baca Al-Qur\'an ${r.quran} '
          'hari.\n\nHari ini: dzikir $dzikirHariIni; Al-Qur\'an '
          '${r.progresQuran.teks}.\n\n'
          'Target hariannya dzikir pagi & sore, plus 10 ayat atau 1 halaman '
          'mushaf.',
      saran: <String>['Cara baca Al-Qur\'an', 'Batas waktu dzikir pagi'],
    );
  }

  BalasanSira _jawabQuran() {
    return const BalasanSira(
      teks:
          'Buka tab Quran, lalu pilih surah. Ada dua mode: per ayat dengan '
          'terjemahan, atau mushaf per halaman — pilihannya di pojok halaman '
          'surah.\n\nIkon audio memutar murottal dan bersambung otomatis sampai '
          'akhir surah. Membaca 10 ayat atau 1 halaman menambah runtutanmu.',
      saran: <String>['Apa itu runtutan?', 'Cara memakai kompas kiblat'],
    );
  }

  BalasanSira _jawabKiblat() {
    return const BalasanSira(
      teks:
          'Arahkan HP mendatar, lalu putar badan sampai panah di layar menunjuk '
          'ke atas.\n\nKalau jarumnya bergerak tidak keruan, jauhkan HP dari '
          'benda logam dan magnet. Di HP tanpa kompas (atau di komputer), pakai '
          'Mode Utara — arah kiblat ditampilkan relatif terhadap utara.',
      saran: <String>['Jadwal sholat hari ini', 'Apa itu runtutan?'],
    );
  }

  BalasanSira _jawabKajian() {
    return const BalasanSira(
      teks:
          'Buka tab Kajian. Jadwal terbaru ada di paling atas, dan kajian hari '
          'ini ditandai.\n\nKajian yang sedang berlangsung diberi lencana LIVE '
          'dan bisa langsung ditonton di dalam aplikasi — tidak perlu pindah ke '
          'YouTube. Ketuk kartunya untuk melihat poster, pemateri, dan lokasi.',
      saran: <String>['Kenapa video tidak muncul?', 'Cara menghubungi pengurus'],
    );
  }

  BalasanSira _jawabFawaidh() {
    return const BalasanSira(
      teks:
          'Fawaidh adalah kumpulan faedah ilmu dari kajian, ditulis ringkas '
          'supaya mudah diingat.\n\nKetuk satu fawaidh untuk membacanya penuh. '
          'Akun ustadz bisa menulis sendiri lewat halaman Fawaidh Saya.',
      saran: <String>['Siapa yang bisa menulis fawaidh?', 'Kajian terbaru kapan?'],
    );
  }

  BalasanSira _jawabVideo() {
    return const BalasanSira(
      teks:
          'Video diputar di dalam aplikasi, jadi kamu tidak perlu pindah ke '
          'YouTube.\n\nKalau videonya tidak muncul: periksa koneksi internet, '
          'lalu coba muat ulang halamannya. Tombol layar penuh membuat '
          'tampilannya lebih lebar.',
      saran: <String>['Kajian terbaru kapan?', 'Cara menghubungi pengurus'],
    );
  }

  BalasanSira _jawabPengaturan() {
    return const BalasanSira(
      teks:
          'Di Pengaturan kamu bisa mengatur:\n'
          '• tema gelap/terang,\n'
          '• notifikasi adzan, dzikir, kajian, dan runtutan satu per satu,\n'
          '• widget layar utama,\n'
          '• tampil atau tidaknya aku (Sira).\n\n'
          'Kartu Status Notifikasi menunjukkan kalau ada izin yang menghalangi '
          'notifikasi.',
      saran: <String>['Kenapa adzan tidak berbunyi?', 'Cara mematikan Sira'],
    );
  }

  BalasanSira _jawabAkun() {
    return const BalasanSira(
      teks:
          'Kamu bisa memakai Insyira tanpa akun (Mode Tamu) — semua fitur '
          'ibadah tetap jalan dan progresnya tersimpan di HP ini.\n\n'
          'Masuk diperlukan untuk fitur yang terkait akun, misalnya Fawaidh Saya '
          'untuk ustadz. Lupa kata sandi bisa diklik di halaman Masuk, dan akun '
          'bisa dihapus lewat tautan di halaman Tentang.',
      saran: <String>['Apa itu fawaidh?', 'Cara menghubungi pengurus'],
    );
  }

  BalasanSira _jawabTentang() {
    return BalasanSira(
      teks:
          '${AppInfo.nama} versi ${AppInfo.versiLengkap}, dikembangkan oleh '
          '${AppInfo.pengembang}.\n\n${AppInfo.deskripsi}',
      saran: const <String>['Cara menghubungi pengurus', 'Apa itu runtutan?'],
    );
  }

  BalasanSira _jawabSira(KonteksSira konteks) {
    return BalasanSira(
      teks:
          'Aku Sira, lentera kecil yang menemani kamu di Insyira. Aku tahu kamu '
          'sedang di halaman ${konteks.judulHalaman}, jadi tips dariku selalu '
          'soal halaman itu.\n\n'
          'Kalau tidak ingin ditemani, tekan lama aku lalu pilih "Sembunyikan '
          'Sira" — bisa dinyalakan lagi di Pengaturan.',
      saran: saranUntuk(konteks),
    );
  }

  BalasanSira _jawabKontak() {
    return BalasanSira(
      teks:
          'Untuk pertanyaan, masukan, atau laporan masalah, hubungi pengurus di '
          '${AppInfo.email}.\n\n'
          'Sebutkan juga versi aplikasimu (ada di halaman Tentang) supaya '
          'masalahnya lebih cepat ditelusuri.',
      saran: const <String>['Versi aplikasi apa?', 'Apa itu Insyira?'],
    );
  }

  BalasanSira _jawabTerimaKasih(KonteksSira konteks) {
    return BalasanSira(
      teks: 'Sama-sama! Semoga harimu berkah. Kalau ada yang ingin ditanyakan '
          'lagi, aku di sini.',
      saran: saranUntuk(konteks),
    );
  }

  BalasanSira _jawabTidakPaham(KonteksSira konteks) {
    return BalasanSira(
      teks:
          'Aku belum paham pertanyaan itu. Aku paling paham soal cara memakai '
          'Insyira — jadwal sholat, kajian, Al-Qur\'an, dzikir, kiblat, dan '
          'pengaturan.\n\nCoba pilih salah satu di bawah ini, ya.',
      saran: saranUntuk(konteks),
    );
  }

  // =====================================================================
  // BANTUAN KECIL
  // =====================================================================
  static const List<String> _urutanSholat = <String>[
    'Subuh',
    'Dzuhur',
    'Ashar',
    'Maghrib',
    'Isya',
  ];

  static bool _jadwalUntukHariIni(
    Map<String, DateTime> jadwal,
    DateTime sekarang,
  ) {
    for (final DateTime waktu in jadwal.values) {
      if (waktu.year == sekarang.year &&
          waktu.month == sekarang.month &&
          waktu.day == sekarang.day) {
        return true;
      }
    }
    return false;
  }

  static String _jam(DateTime waktu) =>
      '${waktu.hour.toString().padLeft(2, '0')}.'
      '${waktu.minute.toString().padLeft(2, '0')}';

  static String _durasi(Duration d) {
    if (d.isNegative) return 'sebentar';
    final int jam = d.inHours;
    final int menit = d.inMinutes.remainder(60);
    if (jam <= 0) return '$menit menit';
    if (menit == 0) return '$jam jam';
    return '$jam jam $menit menit';
  }

  /// Menyeragamkan ejaan supaya satu maksud tidak perlu ditulis berkali-kali.
  static String _rapikan(String teks) {
    String t = teks.toLowerCase().trim();
    t = t.replaceAll(RegExp(r"[^a-z0-9\s']"), ' ');
    t = t.replaceAll("'", '');
    t = t.replaceAll(RegExp(r'\s+'), ' ');

    const Map<String, String> padanan = <String, String>{
      'shalat': 'sholat',
      'solat': 'sholat',
      'zuhur': 'dzuhur',
      'asar': 'ashar',
      'alquran': 'quran',
      'al quran': 'quran',
      'alqur an': 'quran',
      'qur an': 'quran',
      'ngaji': 'quran',
    };
    for (final MapEntry<String, String> e in padanan.entries) {
      t = t.replaceAll(e.key, e.value);
    }
    return t.trim();
  }

  static int _skor(String teks, List<String> kunci) {
    int skor = 0;
    for (final String k in kunci) {
      if (k.contains(' ')) {
        if (_adaFrasa(teks, k)) skor += 2 * k.split(' ').length;
      } else if (_kataAda(teks, k)) {
        skor += 2;
      }
    }
    return skor;
  }

  static bool _adaFrasa(String teks, String frasa) =>
      ' $teks '.contains(' $frasa ');

  /// Pencocokan per kata, toleran terhadap imbuhan: "sholatnya" tetap cocok
  /// dengan "sholat". Kata pendek (<4 huruf) harus sama persis supaya tidak
  /// menangkap kata lain.
  static bool _kataAda(String teks, String kata) {
    for (final String w in teks.split(' ')) {
      if (w == kata) return true;
      if (kata.length >= 4 && w.startsWith(kata)) return true;
      if (w.length >= 4 && kata.startsWith(w)) return true;
    }
    return false;
  }
}

class _Topik {
  const _Topik(this.nama, this.kunci);

  final String nama;
  final List<String> kunci;
}
