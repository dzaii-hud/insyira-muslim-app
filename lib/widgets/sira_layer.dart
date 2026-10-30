import 'dart:async';

import 'package:flutter/material.dart';

import '../router/app_router.dart';
import '../services/sira_pendamping.dart';
import '../services/tips_sira.dart';
import '../theme/app_theme.dart';
import 'sira_mascot.dart';
import 'sira_obrolan_sheet.dart';
import 'sira_pengenalan.dart';
import 'sira_tips_dialog.dart';

/// Lapisan tempat Sira menemani pengguna.
///
/// Dipasang sekali di `MaterialApp.builder`, jadi Sira tidak perlu ditambahkan
/// ke tiap halaman dan posisinya selalu sama. Konsekuensinya: lapisan ini
/// berada DI ATAS Navigator, sehingga membuka lembar (tips, menu, perkenalan)
/// harus lewat `appNavigatorKey`.
class SiraLayer extends StatefulWidget {
  const SiraLayer({super.key, required this.child});

  final Widget child;

  @override
  State<SiraLayer> createState() => _SiraLayerState();
}

class _SiraLayerState extends State<SiraLayer> {
  bool _sudahTawarkanPengenalan = false;

  @override
  void initState() {
    super.initState();
    SiraPendamping.instance.namaHalaman.addListener(_tawarkanPengenalan);

    // Cadangan untuk halaman PERTAMA: observer biasanya sudah melapor sendiri,
    // tetapi kalau belum, alamat router dipakai supaya Sira tidak absen di
    // beranda.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final SiraPendamping sira = SiraPendamping.instance;
      if (sira.namaHalaman.value.isNotEmpty) return;

      final String jalur =
          appRouter.routerDelegate.currentConfiguration.uri.path;
      final String nama = namaHalamanDariJalur(jalur);
      if (nama.isNotEmpty) sira.laporkanHalaman(nama);
    });
  }

  /// Menampilkan perkenalan Sira sekali, saat pengguna pertama kali sampai di
  /// beranda.
  ///
  /// Dicek juga [SiraPendamping.aktif]: pengguna yang pernah mematikan Sira
  /// tidak perlu diperkenalkan lagi.
  void _tawarkanPengenalan() {
    if (_sudahTawarkanPengenalan) return;

    final SiraPendamping sira = SiraPendamping.instance;
    if (sira.pengenalanSelesai.value) return;
    if (!sira.aktif.value) return;
    if (sira.namaHalaman.value != HalamanSira.home) return;

    _sudahTawarkanPengenalan = true;

    // Ditunda satu bingkai: Home baru saja dipasang, dan navigator belum siap
    // menerima lembar baru sebelum bingkai pertamanya selesai.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? konteks =
          appNavigatorKey.currentState?.overlay?.context;
      if (konteks == null) return;
      unawaited(bukaPengenalanSira(konteks));
    });
  }

  @override
  void dispose() {
    SiraPendamping.instance.namaHalaman.removeListener(_tawarkanPengenalan);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: <Widget>[widget.child, const _KehadiranSira()]);
  }
}

class _KehadiranSira extends StatefulWidget {
  const _KehadiranSira();

  @override
  State<_KehadiranSira> createState() => _KehadiranSiraState();
}

class _KehadiranSiraState extends State<_KehadiranSira> {
  /// Sisi gelembung. Cukup besar untuk disentuh jari, cukup kecil untuk tidak
  /// menutupi banyak isi halaman.
  static const double _ukuran = 62;

  /// Jarak minimum dari tepi layar.
  static const double _tepi = 10;

  /// Posisi sementara (piksel) selama jari masih menempel.
  ///
  /// Dipisah dari posisi tersimpan supaya geseran setengah jalan tidak ikut
  /// tersimpan kalau jarinya terlepas.
  Offset? _seret;

  @override
  Widget build(BuildContext context) {
    final SiraPendamping sira = SiraPendamping.instance;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        sira.aktif,
        sira.adaLapisanDiAtas,
        sira.namaHalaman,
        sira.tabHome,
        sira.posisi,
      ]),
      builder: (BuildContext context, Widget? _) {
        final String halaman = sira.namaHalaman.value;
        final TipsSira? tips = cariTipsSira(
          namaHalaman: halaman,
          tab: sira.tabHome.value,
        );

        // Papan tombol menutupi separuh layar; maskot yang menempel di atasnya
        // terlihat sesak.
        final bool papanTombolTerbuka =
            MediaQuery.viewInsetsOf(context).bottom > 0;

        // Halaman yang tidak punya tips berarti memang tidak ingin ditemani
        // Sira (surah, login, splash).
        final bool tampil =
            sira.aktif.value &&
            !sira.adaLapisanDiAtas.value &&
            !papanTombolTerbuka &&
            tips != null;

        // Saat tidak tampil, Sira benar-benar keluar dari pohon widget — bukan
        // sekadar transparan — supaya pembaca layar tidak menemukan tombol
        // tak terlihat.
        if (!tampil) return const SizedBox.shrink();

        final Rect area = _area(context, halaman);
        final Offset posisi = _posisi(context, area, sira.posisi.value);

        return Positioned(
          left: posisi.dx,
          top: posisi.dy,
          child: _gelembung(context, tips),
        );
      },
    );
  }

  /// Ruang yang boleh ditempati gelembung.
  ///
  /// Di Home ruang bawahnya dipotong setinggi menu bawah, supaya Sira tidak
  /// pernah menutupi tombol navigasi walaupun digeser ke paling bawah.
  Rect _area(BuildContext context, String halaman) {
    final MediaQueryData mq = MediaQuery.of(context);
    final double bawah =
        mq.padding.bottom + (halaman == HalamanSira.home ? 78 : 0);

    return Rect.fromLTRB(
      _tepi,
      mq.padding.top + _tepi,
      mq.size.width - _ukuran - _tepi,
      mq.size.height - bawah - _ukuran - _tepi,
    );
  }

  /// Posisi gelembung (kiri-atas) dalam piksel.
  ///
  /// Posisi tersimpan berupa pecahan dari ukuran layar, bukan piksel, supaya
  /// tetap masuk akal saat layar diputar atau dipakai di perangkat lain.
  Offset _posisi(BuildContext context, Rect area, Offset? pecahan) {
    if (_seret != null) return _batasi(_seret!, area);

    if (pecahan == null) {
      // Bawaan: pojok kanan bawah, di atas menu bawah.
      return area.bottomRight;
    }

    final Size layar = MediaQuery.sizeOf(context);
    return _batasi(
      Offset(pecahan.dx * layar.width, pecahan.dy * layar.height),
      area,
    );
  }

  Offset _batasi(Offset posisi, Rect area) => Offset(
    posisi.dx.clamp(area.left, area.right),
    posisi.dy.clamp(area.top, area.bottom),
  );

  void _mulaiSeret(BuildContext context) {
    final SiraPendamping sira = SiraPendamping.instance;
    final Rect area = _area(context, sira.namaHalaman.value);

    setState(() => _seret = _posisi(context, area, sira.posisi.value));
  }

  void _lanjutSeret(BuildContext context, DragUpdateDetails detail) {
    final Offset? sekarang = _seret;
    if (sekarang == null) return;

    final Rect area = _area(context, SiraPendamping.instance.namaHalaman.value);
    setState(() => _seret = _batasi(sekarang + detail.delta, area));
  }

  Future<void> _selesaiSeret(BuildContext context) async {
    final Offset? posisi = _seret;
    if (posisi == null) return;

    final Size layar = MediaQuery.sizeOf(context);
    setState(() => _seret = null);

    await SiraPendamping.instance.simpanPosisi(
      Offset(posisi.dx / layar.width, posisi.dy / layar.height),
    );
  }

  Widget _gelembung(BuildContext context, TipsSira tips) {
    final Color emas = AppColors.getGoldLeaf(context);
    final Color latar = AppColors.getSurfaceContainerLow(context);

    return Semantics(
      button: true,
      label: 'Sira: ${tips.judul}',
      hint: 'Ketuk untuk tips, geser untuk memindahkan, '
          'tekan lama untuk obrolan & opsi',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _bukaTips(tips),
        onLongPress: _bukaMenu,
        onPanStart: (_) => _mulaiSeret(context),
        onPanUpdate: (DragUpdateDetails d) => _lanjutSeret(context, d),
        onPanEnd: (_) => unawaited(_selesaiSeret(context)),
        child: Container(
          width: _ukuran,
          height: _ukuran,
          decoration: BoxDecoration(
            // Gelembung setengah tembus pandang. Sira melayang DI ATAS isi
            // halaman; tanpa latar sendiri ia terbaca sebagai bagian dari
            // kartu yang kebetulan berada di bawahnya.
            color: latar.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            border: Border.all(color: emas.withValues(alpha: 0.32)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(child: SiraMascot(ukuran: 44)),
        ),
      ),
    );
  }

  void _bukaTips(TipsSira tips) {
    final BuildContext? konteks = _konteksNavigator();
    if (konteks == null) return;

    unawaited(bukaTipsSira(konteks, tips));
  }

  void _bukaMenu() {
    final BuildContext? konteks = _konteksNavigator();
    if (konteks == null) return;

    unawaited(
      showModalBottomSheet<void>(
        context: konteks,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) => const _MenuSira(),
      ),
    );
  }

  /// Overlay milik navigator, dipakai karena lapisan ini ada DI ATAS Navigator.
  BuildContext? _konteksNavigator() =>
      appNavigatorKey.currentState?.overlay?.context;
}

/// Menu yang muncul saat Sira ditekan lama.
class _MenuSira extends StatelessWidget {
  const _MenuSira();

  @override
  Widget build(BuildContext context) {
    final Color latar = AppColors.getSurfaceContainerLow(context);
    final Color teks = AppColors.getTextPrimary(context);
    final Color redup = AppColors.getOnSurfaceVariant(context);
    final Color emas = AppColors.getGoldLeaf(context);

    return Container(
      decoration: BoxDecoration(
        color: latar,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: redup.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Row(
                children: <Widget>[
                  const SiraMascot(ukuran: 44, animasi: false),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Atur Sira',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: teks,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.chat_bubble_outline_rounded, color: emas),
              title: Text(
                'Ngobrol dengan Sira',
                style: TextStyle(color: teks, fontSize: 14),
              ),
              subtitle: Text(
                'Tanya apa saja soal aplikasi ini',
                style: TextStyle(color: redup, fontSize: 11.5),
              ),
              onTap: () {
                final NavigatorState navigator = Navigator.of(context);
                final BuildContext? konteks =
                    appNavigatorKey.currentState?.overlay?.context;

                navigator.pop();
                if (konteks != null) unawaited(bukaObrolanSira(konteks));
              },
            ),
            ListTile(
              leading: Icon(Icons.restart_alt_rounded, color: emas),
              title: Text(
                'Kembalikan ke pojok kanan bawah',
                style: TextStyle(color: teks, fontSize: 14),
              ),
              onTap: () async {
                final NavigatorState navigator = Navigator.of(context);
                final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
                  context,
                );

                await SiraPendamping.instance.resetPosisi();
                if (navigator.mounted) navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Sira kembali ke pojok kanan bawah'),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.visibility_off_rounded, color: emas),
              title: Text(
                'Sembunyikan Sira',
                style: TextStyle(color: teks, fontSize: 14),
              ),
              subtitle: Text(
                'Bisa dinyalakan lagi di Pengaturan',
                style: TextStyle(color: redup, fontSize: 11.5),
              ),
              onTap: () async {
                final NavigatorState navigator = Navigator.of(context);
                final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
                  context,
                );

                await SiraPendamping.instance.setAktif(false);
                if (navigator.mounted) navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Sira disembunyikan. Nyalakan lagi kapan saja di '
                      'Pengaturan.',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
