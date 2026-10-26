import 'dart:async';

import 'package:flutter/material.dart';

import '../router/app_router.dart';
import '../services/sira_pendamping.dart';
import '../services/tips_sira.dart';
import '../theme/app_theme.dart';
import 'sira_mascot.dart';
import 'sira_tips_sheet.dart';

/// Lapisan tempat Sira menemani pengguna.
///
/// Dipasang sekali di `MaterialApp.builder`, jadi Sira tidak perlu ditambahkan
/// ke tiap halaman dan posisinya selalu sama. Konsekuensinya: lapisan ini
/// berada DI ATAS Navigator, sehingga membuka lembar tips harus lewat
/// `appNavigatorKey` (lihat [_KehadiranSira._buka]).
class SiraLayer extends StatefulWidget {
  const SiraLayer({super.key, required this.child});

  final Widget child;

  @override
  State<SiraLayer> createState() => _SiraLayerState();
}

class _SiraLayerState extends State<SiraLayer> {
  @override
  void initState() {
    super.initState();
    appRouter.routerDelegate.addListener(_ruteBerubah);
    _ruteBerubah();
  }

  /// Melaporkan alamat halaman ke [SiraPendamping].
  ///
  /// Tab Home tidak bisa dibaca dari URL (berpindah tab tidak mengubah alamat),
  /// jadi di sini hanya alamat yang dilaporkan — Home melaporkan tabnya sendiri.
  void _ruteBerubah() {
    final String jalur = appRouter.routerDelegate.currentConfiguration.uri.path;
    if (jalur.isEmpty) return;
    if (SiraPendamping.instance.rute.value == jalur) return;

    SiraPendamping.instance.rute.value = jalur;
    SiraPendamping.instance.laporkanTabHome(0);
  }

  @override
  void dispose() {
    appRouter.routerDelegate.removeListener(_ruteBerubah);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: <Widget>[widget.child, const _KehadiranSira()]);
  }
}

class _KehadiranSira extends StatelessWidget {
  const _KehadiranSira();

  /// Halaman yang boleh ditemani Sira.
  ///
  /// Halaman baca Al-Qur'an dan pemutar video sengaja TIDAK ada di sini: di
  /// sana pengguna sedang fokus, dan maskot yang melayang justru mengganggu.
  /// Splash/Login juga tidak — belum ada yang perlu dijelaskan.
  static const Set<String> _ruteDiizinkan = <String>{
    AppRoutes.home,
    AppRoutes.fawaidh,
    AppRoutes.fawaidhSaya,
    AppRoutes.settings,
    AppRoutes.about,
  };

  @override
  Widget build(BuildContext context) {
    final SiraPendamping sira = SiraPendamping.instance;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        sira.aktif,
        sira.adaLapisanDiAtas,
        sira.rute,
        sira.tabHome,
      ]),
      builder: (BuildContext context, Widget? _) {
        final String rute = sira.rute.value;
        final TipsSira? tips = cariTipsSira(
          rute: rute,
          tab: sira.tabHome.value,
        );

        // Papan tombol menutupi separuh layar; maskot yang menempel di atasnya
        // terlihat sesak.
        final bool papanTombolTerbuka =
            MediaQuery.viewInsetsOf(context).bottom > 0;

        final bool tampil =
            sira.aktif.value &&
            !sira.adaLapisanDiAtas.value &&
            !papanTombolTerbuka &&
            tips != null &&
            _bolehDitemani(rute);

        return Positioned(
          right: 14,
          bottom: _jarakBawah(context, rute),
          // Visibility (bukan sekadar opacity 0): maskot yang tersembunyi
          // harus benar-benar keluar dari pohon widget, supaya pembaca layar
          // tidak menemukan tombol tak terlihat.
          child: Visibility(
            visible: tampil,
            child: tips == null
                ? const SizedBox.shrink()
                : _tombolSira(context, tips),
          ),
        );
      },
    );
  }

  bool _bolehDitemani(String rute) =>
      _ruteDiizinkan.contains(rute) || rute.startsWith('${AppRoutes.fawaidh}/');

  /// Jarak dari bawah layar.
  ///
  /// Di Home ada bilah menu bawah, jadi Sira duduk di atasnya supaya tidak
  /// menutupi tombol navigasi.
  double _jarakBawah(BuildContext context, String rute) {
    final double aman = MediaQuery.paddingOf(context).bottom;
    return aman + (rute == AppRoutes.home ? 86 : 18);
  }

  Widget _tombolSira(BuildContext context, TipsSira tips) {
    final Color emas = AppColors.getGoldLeaf(context);
    final Color latar = AppColors.getSurfaceContainerLow(context);

    return Semantics(
      button: true,
      label: 'Sira: ${tips.judul}',
      child: Tooltip(
        message: 'Tips dari Sira',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _buka(tips),
          child: Container(
            width: 62,
            height: 62,
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
      ),
    );
  }

  void _buka(TipsSira tips) {
    // Lapisan ini ada di atas Navigator, jadi `context` di sini tidak punya
    // Navigator di atasnya. Overlay milik navigator dipakai supaya lembar
    // tips tetap muncul di atas halaman yang sedang dibuka.
    final BuildContext? konteks =
        appNavigatorKey.currentState?.overlay?.context;
    if (konteks == null) return;

    unawaited(bukaTipsSira(konteks, tips));
  }
}
