import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Perasaan Sira.
///
/// Lentera tidak punya wajah — ekspresinya disampaikan lewat api, cahaya, dan
/// sikap badannya. Itu bukan kekurangan: tanpa mata dan mulut, Sira tidak
/// pernah terlihat "salah gambar", dan tetap pantas untuk pengguna dewasa.
enum SiraEkspresi {
  /// Api berkedip pelan, badan melayang naik-turun.
  diam,

  /// Api lebih besar dan cahaya lebih terang.
  senang,

  /// Badan miring, api mengecil — seperti sedang menimbang sesuatu.
  berpikir,
}

/// Maskot "Sira": lentera kecil yang menemani pengguna.
///
/// Digambar langsung dengan [CustomPainter], bukan dari berkas Lottie/GIF,
/// karena tiga alasan: tidak menambah ukuran aplikasi, warnanya ikut tema
/// terang/gelap, dan bentuknya bisa disesuaikan tanpa meminta bantuan
/// desainer. Kalau nanti ada aset resmi, cukup ganti isi `_PelukisSira`.
class SiraMascot extends StatefulWidget {
  const SiraMascot({
    super.key,
    this.ukuran = 56,
    this.ekspresi = SiraEkspresi.diam,
    this.animasi = true,
  });

  /// Sisi kotak tempat Sira digambar.
  final double ukuran;

  final SiraEkspresi ekspresi;

  /// Dibiarkan mati di dalam lembar tips supaya tidak ada dua animasi
  /// berjalan bersamaan di satu layar.
  final bool animasi;

  @override
  State<SiraMascot> createState() => _SiraMascotState();
}

class _SiraMascotState extends State<SiraMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kontrol = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animasi) _kontrol.repeat();
  }

  @override
  void didUpdateWidget(covariant SiraMascot lama) {
    super.didUpdateWidget(lama);

    if (widget.animasi && !_kontrol.isAnimating) {
      _kontrol.repeat();
    } else if (!widget.animasi && _kontrol.isAnimating) {
      _kontrol.stop();
    }
  }

  @override
  void dispose() {
    _kontrol.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.ukuran,
      height: widget.ukuran,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _kontrol,
          builder: (BuildContext context, Widget? _) => CustomPaint(
            painter: _PelukisSira(
              detik: _kontrol.value,
              ekspresi: widget.ekspresi,
              emas: AppColors.getGoldLeaf(context),
              gelap: Theme.of(context).brightness == Brightness.dark,
            ),
          ),
        ),
      ),
    );
  }
}

class _PelukisSira extends CustomPainter {
  _PelukisSira({
    required this.detik,
    required this.ekspresi,
    required this.emas,
    required this.gelap,
  });

  /// Posisi dalam satu siklus animasi, 0..1.
  final double detik;
  final SiraEkspresi ekspresi;
  final Color emas;
  final bool gelap;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    if (s <= 0) return;

    final bool berpikir = ekspresi == SiraEkspresi.berpikir;
    final bool senang = ekspresi == SiraEkspresi.senang;

    // Api berkedip tiga kali per siklus — cukup hidup, tidak sampai berkedip
    // seperti lampu rusak.
    final double kedip = 1 + 0.11 * math.sin(detik * 2 * math.pi * 3);
    final double skalaApi = kedip * (berpikir ? 0.72 : (senang ? 1.18 : 1));
    final double melayang = berpikir
        ? 0
        : math.sin(detik * 2 * math.pi) * 0.012 * s;

    canvas.save();
    canvas.translate(0, melayang);

    if (berpikir) {
      canvas.translate(s * 0.5, s * 0.62);
      canvas.rotate(0.10);
      canvas.translate(-s * 0.5, -s * 0.62);
    }

    _lukisCahaya(canvas, s, senang);
    _lukisPegangan(canvas, s);
    _lukisTutup(canvas, s);
    _lukisBadan(canvas, s);
    _lukisApi(canvas, s, skalaApi, senang);
    _lukisAlas(canvas, s);

    canvas.restore();
  }

  /// Halo cahaya di belakang lentera.
  void _lukisCahaya(Canvas canvas, double s, bool senang) {
    final Offset pusat = Offset(s * 0.5, s * 0.60);
    final double jariJari = s * 0.48;
    final double kuat = senang ? 0.40 : 0.26;

    canvas.drawCircle(
      pusat,
      jariJari,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            emas.withValues(alpha: kuat),
            emas.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: pusat, radius: jariJari)),
    );
  }

  void _lukisPegangan(Canvas canvas, double s) {
    final Path pegangan = Path()
      ..moveTo(s * 0.355, s * 0.30)
      ..cubicTo(s * 0.355, s * 0.10, s * 0.645, s * 0.10, s * 0.645, s * 0.30);

    canvas.drawPath(
      pegangan,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.042
        ..strokeCap = StrokeCap.round
        ..color = emas,
    );
  }

  void _lukisTutup(Canvas canvas, double s) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.325, s * 0.255, s * 0.35, s * 0.075),
        Radius.circular(s * 0.028),
      ),
      Paint()..color = emas,
    );
  }

  void _lukisBadan(Canvas canvas, double s) {
    final RRect badan = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.245, s * 0.325, s * 0.51, s * 0.47),
      Radius.circular(s * 0.10),
    );

    canvas.drawRRect(
      badan,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            const Color(0xFFFFF3CC).withValues(alpha: gelap ? 0.90 : 0.96),
            const Color(0xFFFFD37A).withValues(alpha: 0.95),
            const Color(0xFFFFB25C).withValues(alpha: 0.92),
          ],
        ).createShader(badan.outerRect),
    );

    // Dua bilah tipis: pembeda lentera dari "bola lampu" biasa.
    final Paint bilah = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.018
      ..color = emas.withValues(alpha: 0.45);

    canvas.save();
    canvas.clipRRect(badan);
    canvas.drawLine(
      Offset(s * 0.375, s * 0.325),
      Offset(s * 0.375, s * 0.795),
      bilah,
    );
    canvas.drawLine(
      Offset(s * 0.625, s * 0.325),
      Offset(s * 0.625, s * 0.795),
      bilah,
    );
    canvas.restore();

    canvas.drawRRect(
      badan,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.042
        ..color = emas,
    );
  }

  void _lukisApi(Canvas canvas, double s, double skala, bool senang) {
    final double tinggi = s * 0.19 * skala;
    final double lebar = s * 0.082;
    final Offset dasar = Offset(s * 0.5, s * 0.705);

    // Sumbu.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(dasar.dx - s * 0.012, dasar.dy, s * 0.024, s * 0.035),
        Radius.circular(s * 0.012),
      ),
      Paint()..color = const Color(0xFF3A2A12).withValues(alpha: 0.75),
    );

    final Path nyala = Path()
      ..moveTo(dasar.dx, dasar.dy - tinggi)
      ..cubicTo(
        dasar.dx + lebar,
        dasar.dy - tinggi * 0.55,
        dasar.dx + lebar * 0.85,
        dasar.dy - tinggi * 0.12,
        dasar.dx,
        dasar.dy,
      )
      ..cubicTo(
        dasar.dx - lebar * 0.85,
        dasar.dy - tinggi * 0.12,
        dasar.dx - lebar,
        dasar.dy - tinggi * 0.55,
        dasar.dx,
        dasar.dy - tinggi,
      );

    final Rect kotakApi = Rect.fromLTRB(
      dasar.dx - lebar * 2,
      dasar.dy - tinggi * 1.4,
      dasar.dx + lebar * 2,
      dasar.dy,
    );

    canvas.drawPath(
      nyala,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.white,
            const Color(0xFFFFE9A8),
            senang ? const Color(0xFFFFA726) : const Color(0xFFFFC15C),
          ],
        ).createShader(kotakApi),
    );
  }

  void _lukisAlas(Canvas canvas, double s) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.275, s * 0.79, s * 0.45, s * 0.075),
        Radius.circular(s * 0.032),
      ),
      Paint()..color = emas,
    );

    // Dua kaki kecil supaya lentera terlihat berdiri, bukan melayang tanpa
    // alasan.
    final Paint kaki = Paint()..color = emas.withValues(alpha: 0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.325, s * 0.845, s * 0.10, s * 0.05),
        Radius.circular(s * 0.02),
      ),
      kaki,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.575, s * 0.845, s * 0.10, s * 0.05),
        Radius.circular(s * 0.02),
      ),
      kaki,
    );
  }

  @override
  bool shouldRepaint(covariant _PelukisSira lama) =>
      lama.detik != detik ||
      lama.ekspresi != ekspresi ||
      lama.emas != emas ||
      lama.gelap != gelap;
}
