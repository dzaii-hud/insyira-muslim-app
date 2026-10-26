import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../router/app_router.dart';
import '../services/youtube_service.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_content.dart';

/// Warna lencana "SEDANG LIVE".
///
/// Satu-satunya warna yang ditulis langsung di halaman ini, karena artinya
/// memang harus terbaca sebagai "siaran langsung" — merah, sama seperti
/// lencana live di YouTube sendiri. Warnanya tetap sama di mode terang maupun
/// gelap karena sudah kontras di atas keduanya.
const Color _kMerahLive = Color(0xFFC62828);

/// Halaman untuk memutar kajian (video biasa maupun siaran langsung)
/// **di dalam aplikasi Insyira**.
///
/// Sebelumnya menekan kartu video melempar user keluar ke aplikasi YouTube.
/// Sekarang videonya diputar di sini.
///
/// Alasannya memakai pemutar resmi YouTube (paket `youtube_player_iframe`
/// yang membungkus **IFrame Player API resmi**) dan bukan memutar berkas
/// videonya sendiri:
///
/// * Menyiarkan ulang / mengekstrak berkas video YouTube melanggar
///   [Ketentuan Layanan YouTube API](https://developers.google.com/youtube/terms/api-services-tos).
/// * Akibatnya akun YouTube Insyira TV bisa kena sanksi — dan itu jauh lebih
///   mahal daripada sekadar tidak bisa memutar video di dalam aplikasi.
///
/// Pemutar resmi juga tetap memberi yang diinginkan user: video muncul di
/// dalam aplikasi, ada tombol layar penuh, pilih kualitas, dan tayangan tetap
/// dihitung sebagai penonton kanal Insyira TV. Yang tidak bisa dihilangkan
/// hanyalah logo YouTube kecil di sudut pemutar — itu memang syarat dari
/// YouTube sendiri.
class TontonScreen extends StatefulWidget {
  const TontonScreen({
    super.key,
    required this.videoId,
    this.judul = '',
    this.kanal = '',
    this.siaranLangsung = false,
  });

  /// ID video YouTube (umumnya 11 karakter, mis. `dQw4w9WgXcQ`).
  final String videoId;

  /// Judul video. Boleh kosong — kalau kosong, judulnya dicari sendiri dari
  /// server (lihat [_TontonScreenState._lengkapiInfo]).
  final String judul;

  /// Nama kanal pemilik video. Boleh kosong.
  final String kanal;

  /// Menampilkan label "LIVE" kalau video ini sedang disiarkan langsung.
  final bool siaranLangsung;

  @override
  State<TontonScreen> createState() => _TontonScreenState();
}

class _TontonScreenState extends State<TontonScreen>
    with WidgetsBindingObserver {
  late final YoutubePlayerController _pengendali;

  /// Judul & kanal yang sedang ditampilkan. Awalnya dari parameter URL,
  /// lalu bisa dilengkapi dari server oleh [_muatDataKajian].
  String _judul = '';
  String _kanal = '';

  /// Benar selama judul masih dicari ke server.
  bool _memuatInfo = false;

  /// Kajian lain di kanal yang sama, ditampilkan di bawah pemutar.
  List<YouTubeVideo> _daftarLain = <YouTubeVideo>[];

  /// Benar selama daftar kajian lain masih diambil.
  bool _memuatLain = true;

  @override
  void initState() {
    super.initState();

    _judul = widget.judul.trim();
    _kanal = widget.kanal.trim();

    // `strictRelatedVideos: true` penting di sini: tanpa itu, saat video
    // selesai YouTube menampilkan daftar video lain dari kanal mana pun —
    // dan itu tidak pantas di aplikasi kajian. Dengan menyala, saran videonya
    // dibatasi ke kanal Insyira TV sendiri.
    //
    // Antarmuka pemutar disetel ke bahasa Indonesia supaya tulisan seperti
    // "Watch later" tidak muncul dalam bahasa Inggris.
    _pengendali = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
        interfaceLanguage: 'id',
        captionLanguage: 'id',
        // Teks tidak dipaksa tampil. Kalau user mau, tombol CC di pemutar
        // tetap bisa menyalakannya sendiri.
        enableCaption: false,
      ),
    );

    WidgetsBinding.instance.addObserver(this);

    // Selalu diambil, untuk DUA keperluan sekaligus:
    //
    // 1. melengkapi judul & nama kanal kalau halaman ini dibuka tanpa
    //    membawanya — mis. saat user menekan notifikasi "kajian live",
    //    karena isi notifikasi hanya memuat ID videonya;
    // 2. mengisi daftar "Kajian lainnya" di bawah pemutar.
    //
    // Digabung dalam satu pengambilan supaya tidak memanggil server dua kali.
    unawaited(_muatDataKajian());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // WAJIB. Tanpa ini, pemutar masih memegang sumber dayanya dan suara video
    // bisa tetap terdengar setelah halaman ditutup.
    unawaited(_pengendali.close());

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // User pindah ke aplikasi lain, mengunci layar, atau pindah tab di
    // peramban. Suara kajian sebaiknya tidak terus berbunyi di latar
    // belakang.
    //
    // `inactive` sengaja TIDAK dihentikan: keadaannya bisa muncul sekejap
    // waktu aplikasi baru dibuka (mis. saat izin/kunci layar muncul), dan
    // kalau ikut dihentikan videonya batal diputar sendiri.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_pengendali.pauseVideo());
    }
  }

  /// Mengambil daftar kajian dari server: untuk melengkapi judul kalau perlu,
  /// sekaligus mengisi daftar "Kajian lainnya".
  ///
  /// Kegagalannya sengaja didiamkan: kalau server tidak bisa dihubungi,
  /// halaman tetap bisa dipakai menonton — yang hilang cuma teks judul dan
  /// daftar kajian lainnya.
  Future<void> _muatDataKajian() async {
    if (mounted) {
      setState(() {
        _memuatInfo = _judul.isEmpty;
        _memuatLain = true;
      });
    }

    try {
      final YouTubeService layanan = YouTubeService();

      // Siaran live didahulukan karena notifikasi hanya dibuat untuk live,
      // jadi halaman yang dibuka dari notifikasi biasanya ada di daftar ini.
      final List<YouTubeVideo> kandidat = <YouTubeVideo>[
        ...await layanan.getLiveVideos(),
        ...await layanan.getLatestVideos(maxResults: 10),
      ];

      for (final YouTubeVideo video in kandidat) {
        if (video.id.trim() == widget.videoId) {
          if (_judul.isEmpty) _judul = video.title.trim();
          if (_kanal.isEmpty) _kanal = video.channelTitle.trim();
          break;
        }
      }

      // Buang video yang sedang ditonton, lalu buang duplikatnya — siaran
      // langsung juga ikut muncul di daftar unggahan, jadi bisa terhitung dua
      // kali kalau tidak disaring.
      final Set<String> sudahAda = <String>{};
      final List<YouTubeVideo> lain = <YouTubeVideo>[];

      for (final YouTubeVideo video in kandidat) {
        final String id = video.id.trim();

        if (id.isEmpty || id == widget.videoId) continue;
        if (!sudahAda.add(id)) continue;

        lain.add(video);
      }

      _daftarLain = lain.take(6).toList();
    } catch (e) {
      debugPrint('Gagal memuat data kajian: $e');
    }

    if (!mounted) return;
    setState(() {
      _memuatInfo = false;
      _memuatLain = false;
    });
  }

  /// Membagikan tautan kajian lewat lembar bagikan HP.
  ///
  /// Tautannya mengarah ke versi WEB aplikasi ini — bukan ke YouTube, dan
  /// bukan ke aplikasi. Penerima tautan belum tentu memasang aplikasinya,
  /// sedangkan halaman web bisa langsung dibuka siapa saja dan tetap memutar
  /// videonya di dalam Insyira.
  Future<void> _bagikanTautan() async {
    final String judul = _judul.isNotEmpty ? _judul : 'Kajian Insyira';
    final String tautan = AppRoutes.tautanTonton(widget.videoId);

    await SharePlus.instance.share(
      ShareParams(
        subject: judul,
        text: '$judul\n\nTonton di Insyira:\n$tautan',
      ),
    );
  }

  /// Pindah ke kajian lain TANPA menumpuk halaman.
  ///
  /// `pushReplacement` dipakai supaya tombol kembali tetap mengarah ke Beranda
  /// walau user sudah beberapa kali berpindah kajian — bukan mundur satu per
  /// satu melewati kajian yang sudah ditonton.
  void _bukaKajian(YouTubeVideo video) {
    context.pushReplacement(
      AppRoutes.tontonVideo(
        videoId: video.id.trim(),
        judul: video.title,
        kanal: video.channelTitle,
        siaranLangsung: video.liveBroadcastContent == 'live',
      ),
    );
  }

  /// Membuka video yang sama di aplikasi YouTube.
  ///
  /// Tetap disediakan sebagai pilihan, bukan jalur utama: sebagian user lebih
  /// suka menonton di aplikasi YouTube supaya bisa menyimpan videonya ke
  /// daftar tonton atau mengatur kualitasnya sendiri.
  Future<void> _bukaDiYouTube() async {
    final Uri url = Uri.parse(
      'https://www.youtube.com/watch?v=${widget.videoId}',
    );

    try {
      final bool dibuka = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!dibuka) _pesanGagal();
    } catch (e) {
      debugPrint('Gagal membuka video di YouTube: $e');
      _pesanGagal();
    }
  }

  void _pesanGagal() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Tidak dapat membuka aplikasi YouTube.'),
        backgroundColor: Colors.red.shade800,
      ),
    );
  }

  // =====================================================================
  // PENANGANAN VIDEO YANG TIDAK BISA DIPUTAR
  // =====================================================================

  /// Area pemutar, atau penjelasan kalau videonya gagal diputar.
  ///
  /// Kegagalan ini NYATA dan cukup sering: sebagian video YouTube tidak
  /// mengizinkan diputar di luar YouTube (penyetingan "Allow embedding" milik
  /// pemilik kanal). Tanpa penanganan ini, yang tampil hanya gambar poster
  /// kosong tanpa keterangan apa pun — dan user mengira aplikasinya rusak.
  Widget _buildAreaPemutar() {
    return YoutubeValueBuilder(
      controller: _pengendali,
      builder: (BuildContext context, nilai) {
        if (nilai.hasError) {
          return _buildPemutarGagal(nilai.error);
        }

        // Pemutar resmi YouTube. Nisbah 16:9 sama seperti YouTube, jadi
        // gambar tidak terpotong dan tidak ada bagian yang hilang.
        return Stack(
          children: <Widget>[
            YoutubePlayer(
              controller: _pengendali,
              aspectRatio: 16 / 9,
              backgroundColor: Colors.black,
            ),

            // Selama pemutarnya belum melaporkan keadaannya sama sekali
            // (masih `unknown`), beri tanda kecil bahwa aplikasi sedang
            // bekerja. Ditaruh sebagai lapisan tipis di sudut, BUKAN menutupi
            // pemutar, supaya gambar poster dari YouTube tetap terlihat —
            // user tahu sedang menunggu, tapi tetap melihat gambaran kajian
            // yang akan diputar.
            if (nilai.playerState == PlayerState.unknown)
              const Positioned(left: 12, bottom: 12, child: _PenandaMemutar()),
          ],
        );
      },
    );
  }

  /// Penjelasan sebab kegagalan, ditulis dengan bahasa yang bisa dimengerti
  /// user — bukan kode angka milik YouTube (101, 150, 152, dst.).
  String _penjelasanGagal(YoutubeError galat) {
    switch (galat) {
      case YoutubeError.notEmbeddable:
      case YoutubeError.sameAsNotEmbeddable:
      case YoutubeError.sameAsNotEmbeddable2:
        return 'Video ini belum diizinkan diputar di aplikasi lain. '
            'Silakan tonton lewat aplikasi YouTube.';
      case YoutubeError.videoNotFound:
      case YoutubeError.cannotFindVideo:
        return 'Video ini sudah dihapus atau dijadikan pribadi oleh pemiliknya.';
      case YoutubeError.invalidParam:
        return 'Tautan video ini tidak sah.';
      case YoutubeError.html5Error:
        return 'Pemutar tidak berhasil memuat video ini.';
      case YoutubeError.unknown:
        return 'Terjadi gangguan saat memutar video.';
      case YoutubeError.none:
        return 'Video ini tidak dapat diputar.';
    }
  }

  /// Yang tampil menggantikan pemutar kalau videonya gagal diputar.
  ///
  /// Tingginya disamakan dengan pemutar (16:9) supaya tata letaknya tidak
  /// meloncat saat beralih dari pemutar ke pesan ini. Warnanya mengikuti tema
  /// aplikasi supaya senada dengan halaman lain, di mode terang maupun gelap.
  Widget _buildPemutarGagal(YoutubeError galat) {
    final bool modeGelap = Theme.of(context).brightness == Brightness.dark;
    final Color redup = AppColors.getOnSurfaceVariant(context);
    final Color teks = AppColors.getTextPrimary(context);
    final Color emas = AppColors.getGoldLeaf(context);

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: AppColors.getSurfaceVariant(context),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.videocam_off_rounded, color: redup, size: 32),
            const SizedBox(height: 12),
            Text(
              _penjelasanGagal(galat),
              textAlign: TextAlign.center,
              style: TextStyle(color: teks, fontSize: 13.5, height: 1.45),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: <Widget>[
                TextButton.icon(
                  onPressed: _muatUlang,
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('Coba lagi'),
                  style: TextButton.styleFrom(foregroundColor: redup),
                ),
                FilledButton.icon(
                  onPressed: _bukaDiYouTube,
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: const Text('Tonton di YouTube'),
                  style: FilledButton.styleFrom(
                    backgroundColor: emas,
                    // Emas TERANG perlu tulisan gelap, emas TUA perlu tulisan
                    // putih. Tanpa ini tulisannya tidak terbaca di salah satu
                    // mode.
                    foregroundColor: modeGelap
                        ? const Color(0xFF231B07)
                        : Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Memuat ulang videonya, dipakai tombol "Coba lagi".
  ///
  /// Status error TIDAK perlu dibersihkan manual: paketnya sendiri yang
  /// mengembalikannya ke [YoutubeError.none] begitu keadaan pemutar berubah.
  void _muatUlang() {
    unawaited(_pengendali.loadVideoById(videoId: widget.videoId));
  }

  @override
  Widget build(BuildContext context) {
    // Latar dan bilah judul TIDAK disetel di sini, supaya mengikuti tema
    // aplikasi. Sebelumnya halaman ini dikunci gelap, sehingga di mode terang
    // warnanya bertabrakan dengan halaman lain.
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => popOrHome(context),
        ),
        centerTitle: true,
        title: Text(
          widget.siaranLangsung ? 'Kajian Langsung' : 'Kajian Online',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Area pemutar beserta penanganan kalau videonya gagal diputar.
              _buildAreaPemutar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  child: _buildKeterangan(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Isi di bawah pemutar: judul, tombol aksi, kajian lainnya, dan catatan.
  Widget _buildKeterangan() {
    final Color redup = AppColors.getOnSurfaceVariant(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.siaranLangsung) ...<Widget>[
          _buildLabelLive(),
          const SizedBox(height: 14),
        ],
        _buildJudul(),
        if (_kanal.isNotEmpty) ...<Widget>[
          const SizedBox(height: 9),
          Row(
            children: <Widget>[
              Icon(Icons.account_circle_rounded, size: 17, color: redup),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _kanal,
                  style: TextStyle(color: redup, fontSize: 13.5, height: 1.4),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),

        // Dua tombol yang paling mungkin dibutuhkan user. Dibuat lebar dan
        // berpasangan supaya jelas dan mudah ditekan — sebelumnya hanya ada
        // satu tombol kecil di bawah dan mudah terlewat.
        Row(
          children: <Widget>[
            Expanded(
              child: _tombolAksi(
                ikon: Icons.share_rounded,
                label: 'Bagikan',
                onTap: _bagikanTautan,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _tombolAksi(
                ikon: Icons.open_in_new_rounded,
                label: 'Buka di YouTube',
                onTap: _bukaDiYouTube,
              ),
            ),
          ],
        ),

        const SizedBox(height: 26),
        Divider(color: Theme.of(context).dividerColor, height: 1),
        const SizedBox(height: 22),

        _buildKajianLain(),
        const SizedBox(height: 22),
        _buildCatatan(),
      ],
    );
  }

  /// Tombol aksi yang warnanya mengikuti tema aplikasi.
  ///
  /// Dibuat sendiri (bukan OutlinedButton) supaya tingginya cukup untuk
  /// ditekan jari dan warnanya otomatis menyesuaikan mode terang/gelap.
  Widget _tombolAksi({
    required IconData ikon,
    required String label,
    required VoidCallback onTap,
  }) {
    final Color warna = AppColors.getPrimaryText(context);

    return Material(
      color: AppColors.getSurfaceVariant(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(ikon, size: 18, color: warna),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: warna,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Daftar kajian lain di kanal yang sama.
  ///
  /// Tanpa ini, setelah selesai menonton user harus menekan "Kembali" ke
  /// Beranda dulu sebelum bisa memilih kajian berikutnya — dan di situlah
  /// kebanyakan orang berhenti menonton. Daftar ini membuat user bisa lanjut
  /// menonton tanpa keluar dari halaman, sama seperti di YouTube.
  Widget _buildKajianLain() {
    if (_memuatLain) {
      return const Row(
        children: <Widget>[
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text('Memuat kajian lainnya...', style: TextStyle(fontSize: 13)),
        ],
      );
    }

    if (_daftarLain.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Kajian lainnya',
          style: TextStyle(
            color: AppColors.getTextPrimary(context),
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        for (final YouTubeVideo video in _daftarLain) _buildBarisKajian(video),
      ],
    );
  }

  /// Satu baris kajian lain: gambar kecil, judul, dan nama kanal.
  Widget _buildBarisKajian(YouTubeVideo video) {
    final Color teks = AppColors.getTextPrimary(context);
    final Color redup = AppColors.getOnSurfaceVariant(context);
    final Color isian = AppColors.getSurfaceVariant(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.getSurfaceContainerLow(context),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _bukaKajian(video),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isian),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 124,
                    height: 70,
                    child: video.thumbnailUrl.isEmpty
                        ? _gambarCadangan(isian, redup)
                        : Image.network(
                            video.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (
                                  BuildContext context,
                                  Object galat,
                                  StackTrace? jejak,
                                ) => _gambarCadangan(isian, redup),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: teks,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        video.channelTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: redup, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Gambar pengganti kalau video tidak punya gambar pratinjau, atau
  /// gambarnya gagal diunduh (mis. sedang tidak ada internet).
  Widget _gambarCadangan(Color isian, Color redup) {
    return Container(
      color: isian,
      child: Icon(Icons.video_library_outlined, color: redup),
    );
  }

  /// Catatan kecil soal sumber tayangan.
  Widget _buildCatatan() {
    final Color redup = AppColors.getOnSurfaceVariant(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.info_outline_rounded, size: 15, color: redup),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Kajian ini diputar lewat pemutar resmi YouTube, jadi tayangannya '
            'tetap berasal dari kanal Insyira TV dan terhitung sebagai penonton '
            'di sana.',
            style: TextStyle(color: redup, fontSize: 12.5, height: 1.5),
          ),
        ),
      ],
    );
  }

  /// Judul video, atau penanda kalau judulnya masih dicari.
  Widget _buildJudul() {
    if (_judul.isNotEmpty) {
      return Text(
        _judul,
        style: TextStyle(
          color: AppColors.getTextPrimary(context),
          fontSize: 19,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      );
    }

    if (_memuatInfo) {
      return const Row(
        children: <Widget>[
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text('Memuat judul kajian...', style: TextStyle(fontSize: 14)),
        ],
      );
    }

    return Text(
      'Kajian Insyira TV',
      style: TextStyle(
        color: AppColors.getTextPrimary(context),
        fontSize: 19,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
    );
  }

  /// Lencana merah "SEDANG LIVE".
  Widget _buildLabelLive() {
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _kMerahLive,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.podcasts_rounded, size: 13, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'SEDANG LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Penanda kecil di sudut pemutar selama pemutarnya belum siap.
///
/// Warnanya sengaja tetap gelap dengan tulisan putih — penanda ini selalu
/// berada di atas area pemutar yang memang hitam, di mode terang maupun gelap.
class _PenandaMemutar extends StatelessWidget {
  const _PenandaMemutar();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0xB0000000),
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 9),
            Text(
              'Menyiapkan pemutar...',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
