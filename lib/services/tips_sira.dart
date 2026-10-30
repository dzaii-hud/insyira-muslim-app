import '../router/app_router.dart';

/// Satu kumpulan tips yang ditampilkan Sira di sebuah halaman.
class TipsSira {
  const TipsSira({required this.judul, required this.poin});

  /// Judul singkat, mis. "Jadwal Kajian".
  final String judul;

  /// 3–4 kalimat pendek. Sengaja pendek: tips yang panjang tidak dibaca.
  final List<String> poin;
}

/// Nama route halaman yang ditemani Sira.
///
/// Harus sama dengan `name:` pada [appRouter]. Halaman yang tidak ada di sini
/// (surah, login, splash) sengaja tidak ditemani: di sana pengguna sedang
/// fokus membaca atau belum ada yang perlu dijelaskan.
class HalamanSira {
  HalamanSira._();

  static const String home = 'home';
  static const String fawaidh = 'fawaidh';
  static const String fawaidhBaca = 'fawaidh-baca';
  static const String fawaidhSaya = 'fawaidh-saya';
  static const String pengaturan = 'settings';
  static const String tentang = 'tentang';
  static const String tonton = 'tonton';
}

/// Tips untuk tiap tab di halaman Home.
///
/// Nomornya mengikuti `kNavDestinations` (Home, Quran, Qibla, Kajian, Dzikir).
const Map<int, TipsSira> kTipsSiraHome = <int, TipsSira>{
  0: TipsSira(
    judul: 'Selamat datang di Beranda',
    poin: <String>[
      'Kartu besar di atas adalah waktu sholat berikutnya, lengkap dengan '
          'hitungan mundurnya.',
      'Kartu Runtutan Harian menghitung hari berturut-turut kamu dzikir dan '
          'membaca. Tekan untuk melihat rinciannya.',
      'Di bagian Jadwal Kajian, ketuk kartunya untuk melihat rincian. Kalau '
          'kajian sedang live, ketukan langsung memutar siarannya.',
    ],
  ),
  1: TipsSira(
    judul: 'Membaca Al-Qur\'an',
    poin: <String>[
      'Kartu Terakhir Dibaca membawamu kembali ke ayat yang terakhir kamu buka.',
      'Ada dua mode: per ayat (dengan terjemahan) dan mushaf per halaman. '
          'Pilihannya ada di pojok halaman surah.',
      'Tekan ikon audio untuk memutar murottal; bacaannya bersambung otomatis '
          'sampai akhir surah.',
    ],
  ),
  2: TipsSira(
    judul: 'Arah Kiblat',
    poin: <String>[
      'Arahkan HP mendatar, lalu putar badan sampai panah di layar menunjuk '
          'ke atas.',
      'Kalau jarumnya bergerak tidak keruan, jauhkan HP dari benda logam dan '
          'magnet.',
      'Di HP tanpa sensor kompas (atau di komputer), gunakan Mode Utara: arah '
          'kiblat ditampilkan relatif terhadap utara, dan kamu memutar sendiri.',
    ],
  ),
  3: TipsSira(
    judul: 'Jadwal Kajian',
    poin: <String>[
      'Kajian hari ini ditandai; yang sedang berlangsung diberi lencana LIVE.',
      'Ketuk kajian mana pun untuk melihat poster, pemateri, waktu, dan lokasi.',
      'Kajian yang sedang live bisa langsung ditonton dari dalam aplikasi — '
          'tidak perlu pindah ke YouTube.',
    ],
  ),
  4: TipsSira(
    judul: 'Dzikir Pagi & Sore',
    poin: <String>[
      'Dzikir pagi bisa dikerjakan sampai pukul 11.00, dzikir sore sampai '
          'pukul 18.00.',
      'Kalau waktunya sudah lewat, sesi itu ditandai terlewat — bukan '
          '"belum", karena memang sudah tidak bisa dikerjakan.',
      'Menyelesaikan dzikir pagi dan sore serta membaca Al-Qur\'an menambah '
          'runtutan harianmu.',
    ],
  ),
};

/// Tips untuk halaman selain Home, dikunci dengan nama route-nya.
const Map<String, TipsSira> kTipsSiraHalaman = <String, TipsSira>{
  HalamanSira.fawaidh: TipsSira(
    judul: 'Fawaidh',
    poin: <String>[
      'Fawaidh adalah kumpulan faedah ilmu dari kajian, ditulis ringkas supaya '
          'mudah diingat.',
      'Ketuk satu fawaidh untuk membacanya penuh; teksnya bisa diperbesar dari '
          'pengaturan ukuran teks di HP-mu.',
    ],
  ),
  HalamanSira.fawaidhBaca: TipsSira(
    judul: 'Membaca Fawaidh',
    poin: <String>[
      'Geser ke bawah untuk melanjutkan bacaan.',
      'Ketuk poster di bagian atas kalau ingin memperbesar gambarnya.',
    ],
  ),
  HalamanSira.fawaidhSaya: TipsSira(
    judul: 'Fawaidh Saya',
    poin: <String>[
      'Halaman ini khusus untuk akun yang terdaftar sebagai ustadz.',
      'Dari sini kamu bisa menulis fawaidh baru dan mengelola yang sudah '
          'terbit.',
    ],
  ),
  HalamanSira.pengaturan: TipsSira(
    judul: 'Pengaturan',
    poin: <String>[
      'Notifikasi bisa diatur satu per satu: adzan, pengingat dzikir, jadwal '
          'kajian, dan pengingat runtutan.',
      'Kalau adzan tidak berbunyi, buka kartu Status Notifikasi — di situ '
          'terlihat apakah izin dan penghemat baterai HP menghalanginya.',
      'Di bagian bawah ada pilihan widget layar utama, sakelar untuk mematikan '
          'Sira, dan tombol untuk melihat perkenalannya lagi.',
    ],
  ),
  HalamanSira.tentang: TipsSira(
    judul: 'Tentang Aplikasi',
    poin: <String>[
      'Nomor versi dan nomor build ada di sini — sebutkan keduanya kalau kamu '
          'melaporkan masalah.',
      'Ada tautan ke kanal YouTube kajian dan kontak pengurus.',
    ],
  ),
  HalamanSira.tonton: TipsSira(
    judul: 'Memutar Video Kajian',
    poin: <String>[
      'Video diputar langsung di dalam aplikasi, jadi kamu tidak perlu pindah '
          'ke YouTube.',
      'Ketuk tombol layar penuh untuk menonton lebih lebar; tombol kembali '
          'menutup pemutar.',
      'Kalau videonya tidak muncul, periksa koneksi internet lalu coba lagi.',
    ],
  ),
};

/// Tips yang cocok untuk halaman yang sedang dibuka.
///
/// Mengembalikan `null` kalau halamannya memang tidak ingin ditemani Sira
/// (mis. halaman baca Al-Qur'an).
TipsSira? cariTipsSira({required String namaHalaman, required int tab}) {
  if (namaHalaman == HalamanSira.home) {
    return kTipsSiraHome[tab] ?? kTipsSiraHome[0];
  }

  return kTipsSiraHalaman[namaHalaman];
}

/// Menebak nama halaman dari alamat URL.
///
/// Hanya dipakai sebagai cadangan untuk halaman PERTAMA saat aplikasi dibuka,
/// kalau observer belum sempat melapor. Sesudah itu [SiraObserver] yang
/// menjadi sumber kebenaran.
String namaHalamanDariJalur(String jalur) {
  if (jalur == AppRoutes.home) return HalamanSira.home;
  if (jalur == AppRoutes.fawaidh) return HalamanSira.fawaidh;
  if (jalur.startsWith('${AppRoutes.fawaidh}/')) return HalamanSira.fawaidhBaca;
  if (jalur == AppRoutes.fawaidhSaya) return HalamanSira.fawaidhSaya;
  if (jalur == AppRoutes.settings) return HalamanSira.pengaturan;
  if (jalur == AppRoutes.about) return HalamanSira.tentang;
  if (jalur.startsWith('${AppRoutes.tonton}/')) return HalamanSira.tonton;
  return '';
}
