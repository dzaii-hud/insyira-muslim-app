import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Latar belakang foto untuk kartu Kajian.
///
/// Tujuan utamanya: memastikan foto SELALU menutup seluruh area kartu,
/// sehingga tidak ada bagian kartu yang menganga / menyisakan warna terang
/// di sisi kiri-kanan foto (yang bikin kelihatan "nyisa").
///
/// Susunan lapisan dari bawah ke atas:
///
/// 1. **Gradasi hijau gelap** — jaring pengaman, tidak pernah berwarna putih.
///    Selalu ada, walaupun foto gagal dimuat.
/// 2. **Foto versi blur** — foto yang sama tapi direntangkan penuh
///    (`BoxFit.fill`) lalu di-blur. Lapisan inilah yang menutup area yang
///    tidak tercakup oleh foto utama (misal foto potret/kepotong atau foto
///    PNG dengan area transparan), jadi tidak ada celah kosong sama sekali.
/// 3. **Foto asli** — `BoxFit.cover`, tampil tajam di lapisan atas.
/// 4. **Lapisan gelap** (opsional) — supaya teks di atas foto tetap terbaca.
///
/// Catatan performa: lapisan 2 dan 3 memakai URL yang sama, sehingga
/// `ImageCache` Flutter hanya mengunduh & mendekode gambar satu kali.
class KajianCardBackground extends StatelessWidget {
  const KajianCardBackground({
    super.key,
    required this.photoUrl,
    this.overlayOpacity = 0.0,
    this.blurSigma = 18.0,
    this.plainBaseColor,
  });

  /// URL foto. Boleh null atau string kosong — kalau begitu hanya gradasi
  /// dasar yang dipakai.
  final String? photoUrl;

  /// Opasitas lapisan hitam di atas foto (0 - 1).
  final double overlayOpacity;

  /// Kekuatan blur untuk lapisan pengisi.
  final double blurSigma;

  /// Warna dasar yang dipakai ketika [photoUrl] kosong.
  ///
  /// Isi dengan warna surface tema (bukan gradasi gelap) supaya teks dengan
  /// warna tema tetap terbaca saat kartu tidak memakai foto.
  final Color? plainBaseColor;

  static const List<Color> _baseGradient = <Color>[
    Color(0xFF003527),
    Color(0xFF00120B),
  ];

  @override
  Widget build(BuildContext context) {
    final String url = (photoUrl ?? '').trim();
    final bool hasPhoto = url.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // ---------------------------------------------------------------
        // 1. Lapisan dasar (tidak pernah putih saat ada foto).
        // ---------------------------------------------------------------
        if (hasPhoto)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _baseGradient,
              ),
            ),
          )
        else
          ColoredBox(color: plainBaseColor ?? _baseGradient.first),

        if (hasPhoto) ...<Widget>[
          // -------------------------------------------------------------
          // 2. Lapisan pengisi: foto direntangkan penuh lalu di-blur.
          // -------------------------------------------------------------
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: blurSigma,
              sigmaY: blurSigma,
              tileMode: TileMode.clamp,
            ),
            child: Image.network(
              url,
              fit: BoxFit.fill,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),

          // -------------------------------------------------------------
          // 3. Foto asli (tajam) di atas lapisan pengisi.
          // -------------------------------------------------------------
          Image.network(
            url,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                child: child,
              );
            },
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ],

        // ---------------------------------------------------------------
        // 4. Lapisan gelap opsional.
        // ---------------------------------------------------------------
        if (hasPhoto && overlayOpacity > 0)
          ColoredBox(color: Colors.black.withOpacity(overlayOpacity)),
      ],
    );
  }
}
