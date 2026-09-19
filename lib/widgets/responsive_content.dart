import 'package:flutter/material.dart';

/// Lebar maksimum isi halaman.
///
/// Tanpa batas ini, di monitor lebar tulisan dan kartu ikut melar
/// mengikuti layar sehingga melelahkan dibaca.
const double kMaxContentWidth = 820;

/// Di atas lebar ini, aplikasi beralih ke tata letak desktop: menu pindah
/// ke samping (NavigationRail) dan menu bawah dihilangkan.
const double kBreakpointDesktop = 900;

/// Membungkus isi halaman supaya lebarnya tidak melebihi [maxWidth] dan
/// tetap berada di tengah layar.
///
/// Dipakai di halaman yang bisa dibuka langsung dari URL (Fawaidh,
/// Pengaturan, Detail Surah). Tab di dalam Home sudah dibatasi lewat
/// `_buildTabContent()` di `home_screen.dart`.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = kMaxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
