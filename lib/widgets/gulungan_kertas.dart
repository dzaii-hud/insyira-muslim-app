import 'package:flutter/material.dart';

/// Membuka isi seperti gulungan kertas yang sedang dibuka.
///
/// Isinya TIDAK ikut menyusut selama animasi — yang berubah hanya bagian yang
/// terlihat (dipotong), jadi huruf tidak pernah gepeng. Dua batang di atas dan
/// bawah menandai tepi gulungan, dan keduanya bergerak saling menjauh sampai
/// seluruh isi terbuka.
class GulunganKertas extends StatefulWidget {
  const GulunganKertas({
    super.key,
    required this.child,
    required this.warnaRol,
    this.durasi = const Duration(milliseconds: 480),
  });

  final Widget child;

  /// Warna batang gulungan (dipakai juga untuk ujung batangnya).
  final Color warnaRol;

  final Duration durasi;

  @override
  State<GulunganKertas> createState() => _GulunganKertasState();
}

class _GulunganKertasState extends State<GulunganKertas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kontrol = AnimationController(
    vsync: this,
    duration: widget.durasi,
  )..forward();

  @override
  void dispose() {
    _kontrol.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _kontrol,
      builder: (BuildContext context, Widget? _) {
        final double t = Curves.easeOutCubic.transform(_kontrol.value);

        return Stack(
          children: <Widget>[
            ClipPath(
              clipper: _KlipGulungan(t),
              child: Opacity(
                // Isi muncul sedikit lebih lambat daripada gulungannya, supaya
                // tidak terlihat seperti teks yang terpotong setengah huruf.
                opacity: (t * 1.5).clamp(0.0, 1.0),
                child: widget.child,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PelukisRol(t: t, warna: widget.warnaRol),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Memotong isi menjadi pita di tengah yang tingginya mengikuti animasi.
class _KlipGulungan extends CustomClipper<Path> {
  _KlipGulungan(this.t);

  final double t;

  @override
  Path getClip(Size size) {
    final double tinggi = size.height * t;
    final Rect pita = Rect.fromLTWH(
      0,
      (size.height - tinggi) / 2,
      size.width,
      tinggi,
    );

    return Path()
      ..addRRect(RRect.fromRectAndRadius(pita, const Radius.circular(18)));
  }

  @override
  bool shouldReclip(_KlipGulungan lama) => lama.t != t;
}

/// Batang gulungan di tepi atas dan bawah bagian yang sedang terlihat.
class _PelukisRol extends CustomPainter {
  _PelukisRol({required this.t, required this.warna});

  final double t;
  final Color warna;

  static const double _tebal = 11;

  @override
  void paint(Canvas canvas, Size size) {
    final double tinggi = size.height * t;
    final double atas = (size.height - tinggi) / 2;

    _batang(canvas, size.width, atas);
    _batang(canvas, size.width, atas + tinggi);
  }

  void _batang(Canvas canvas, double lebar, double y) {
    final Rect batang = Rect.fromLTWH(0, y - _tebal / 2, lebar, _tebal);

    canvas.drawRRect(
      RRect.fromRectAndRadius(batang, const Radius.circular(_tebal / 2)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            warna.withValues(alpha: 0.95),
            warna,
            warna.withValues(alpha: 0.75),
          ],
        ).createShader(batang),
    );

    // Ujung batang: bulatan kecil yang memberi kesan kayu digenggam.
    final Paint ujung = Paint()..color = warna.withValues(alpha: 0.6);
    canvas.drawCircle(Offset(_tebal, y), 7, ujung);
    canvas.drawCircle(Offset(lebar - _tebal, y), 7, ujung);
  }

  @override
  bool shouldRepaint(_PelukisRol lama) => lama.t != t || lama.warna != warna;
}
