import 'package:flutter/material.dart';

import '../screens/kajian_screen.dart';
import '../theme/app_theme.dart';

/// Membuka rincian satu kajian dalam lembar bawah layar penuh.
///
/// Dipakai dari daftar kajian. Sengaja berupa lembar bawah, bukan halaman
/// terpisah, supaya pengguna bisa menutupnya kembali ke posisi daftar semula
/// tanpa kehilangan posisi gulir.
Future<void> bukaRincianKajian(BuildContext context, Kajian kajian) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => KajianRincian(kajian: kajian),
  );
}

class KajianRincian extends StatelessWidget {
  const KajianRincian({super.key, required this.kajian});

  final Kajian kajian;

  static const List<String> _namaHari = <String>[
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  static const List<String> _namaBulan = <String>[
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  DateTime? get _mulai =>
      DateTime.tryParse('${kajian.tanggal} ${kajian.jamMulai}:00');

  DateTime? get _selesai =>
      DateTime.tryParse('${kajian.tanggal} ${kajian.jamSelesai}:00');

  /// "Selasa, 20 Oktober 2026"
  String get _tanggalPanjang {
    final DateTime? mulai = _mulai;
    if (mulai == null) return kajian.tanggal;

    return '${_namaHari[mulai.weekday - 1]}, ${mulai.day} '
        '${_namaBulan[mulai.month - 1]} ${mulai.year}';
  }

  /// "18:35 – 20:00 WIB", atau hanya jam mulai kalau jam selesai kosong.
  String get _rentangJam {
    if (kajian.jamSelesai.isEmpty) return '${kajian.jamMulai} WIB';
    return '${kajian.jamMulai} – ${kajian.jamSelesai} WIB';
  }

  /// Keadaan kajian sekarang: sedang berlangsung, belum dimulai, atau sudah lewat.
  ({String label, Color warnaLatar, Color warnaTeks}) _status(
    BuildContext context,
  ) {
    final Color emas = AppColors.getGoldLeaf(context);
    final DateTime sekarang = DateTime.now();
    final DateTime? mulai = _mulai;
    final DateTime? selesai = _selesai;

    if (mulai != null && mulai.isAfter(sekarang)) {
      return (
        label: 'AKAN BERLANGSUNG',
        warnaLatar: emas.withValues(alpha: 0.18),
        warnaTeks: emas,
      );
    }

    if (selesai != null && selesai.isAfter(sekarang)) {
      return (
        label: 'SEDANG BERLANGSUNG',
        warnaLatar: emas,
        warnaTeks: const Color(0xFF00120B),
      );
    }

    return (
      label: 'SUDAH BERLALU',
      warnaLatar: AppColors.getSurfaceVariant(context).withValues(alpha: 0.5),
      warnaTeks: AppColors.getOnSurfaceVariant(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color latar = AppColors.getSurfaceContainerLow(context);
    final String? poster = _urlGambar(kajian.fotoPoster);
    final String? fotoUstadz = _urlGambar(kajian.fotoUstadz);

    // Kajian lama belum punya poster; foto ustadz dipakai supaya bagian atas
    // rincian tidak kosong melompong.
    final String? gambarUtama = poster ?? fotoUstadz;

    final ({String label, Color warnaLatar, Color warnaTeks}) status = _status(
      context,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.4,
      maxChildSize: 0.96,
      expand: false,
      builder: (BuildContext context, ScrollController gulir) {
        return Container(
          decoration: BoxDecoration(
            color: latar,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Pegangan untuk menutup/menarik lembar.
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.getOnSurfaceVariant(
                      context,
                    ).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: gulir,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (gambarUtama != null)
                        _gambarPoster(
                          context,
                          gambarUtama,
                          poster != null ? fotoUstadz : null,
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _lencanaStatus(context, status),
                            const SizedBox(height: 12),
                            Text(
                              kajian.judul,
                              style: TextStyle(
                                fontSize: 21,
                                height: 1.35,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _barisInfo(
                              context,
                              ikon: Icons.person_rounded,
                              label: 'Pemateri',
                              nilai: kajian.ustadz,
                            ),
                            _barisInfo(
                              context,
                              ikon: Icons.event_rounded,
                              label: 'Tanggal',
                              nilai: _tanggalPanjang,
                            ),
                            _barisInfo(
                              context,
                              ikon: Icons.schedule_rounded,
                              label: 'Waktu',
                              nilai: _rentangJam,
                            ),
                            if (kajian.lokasi.trim().isNotEmpty)
                              _barisInfo(
                                context,
                                ikon: Icons.place_rounded,
                                label: 'Lokasi',
                                nilai: kajian.lokasi,
                              ),
                            if (kajian.deskripsi.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _bagianDeskripsi(context),
                            ],
                            SizedBox(
                              height:
                                  24 + MediaQuery.of(context).padding.bottom,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =====================================================================
  // BAGIAN-BAGIAN
  // =====================================================================
  Widget _lencanaStatus(
    BuildContext context,
    ({String label, Color warnaLatar, Color warnaTeks}) status,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status.warnaLatar,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
          color: status.warnaTeks,
        ),
      ),
    );
  }

  /// Poster ditampilkan UTUH (BoxFit.contain) — dipotong sedikit pun bisa
  /// menghilangkan tulisan jadwal yang ada di pinggir desain poster.
  Widget _gambarPoster(
    BuildContext context,
    String poster,
    String? fotoUstadz,
  ) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF00120B)
          : const Color(0xFFE8F0EB),
      child: GestureDetector(
        onTap: () => _bukaPosterPenuh(context, poster),
        child: Image.network(
          poster,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progres) {
            if (progres == null) return child;
            return SizedBox(
              height: 220,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.getGoldLeaf(context),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stack) =>
              _gambarCadangan(context, fotoUstadz),
        ),
      ),
    );
  }

  /// Kalau poster gagal dimuat tapi ada foto ustadz, pakai foto itu daripada
  /// menampilkan kotak rusak.
  Widget _gambarCadangan(BuildContext context, String? fotoUstadz) {
    if (fotoUstadz == null) {
      return SizedBox(
        height: 140,
        child: Center(
          child: Text(
            'Poster tidak bisa dimuat',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.getOnSurfaceVariant(context),
            ),
          ),
        ),
      );
    }

    return Image.network(
      fotoUstadz,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) => const SizedBox(height: 120),
    );
  }

  void _bukaPosterPenuh(BuildContext context, String poster) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _PosterPenuh(url: poster),
      ),
    );
  }

  Widget _barisInfo(
    BuildContext context, {
    required IconData ikon,
    required String label,
    required String nilai,
  }) {
    final Color emas = AppColors.getGoldLeaf(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: emas.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(ikon, size: 17, color: emas),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.3,
                    color: AppColors.getOnSurfaceVariant(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  nilai,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bagianDeskripsi(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceVariant(context).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.getGoldLeaf(context).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tentang kajian',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.getGoldLeaf(context),
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            kajian.deskripsi,
            style: TextStyle(
              fontSize: 14,
              height: 1.7,
              color: AppColors.getTextPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Membuang spasi di ujung dan menganggap teks kosong sebagai "tidak ada".
  static String? _urlGambar(String? url) {
    final String bersih = (url ?? '').trim();
    return bersih.isEmpty ? null : bersih;
  }
}

/// Poster ukuran penuh — bisa dicubit untuk memperbesar.
class _PosterPenuh extends StatelessWidget {
  const _PosterPenuh({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Tutup',
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progres) {
              if (progres == null) return child;
              return const CircularProgressIndicator(color: Colors.white);
            },
            errorBuilder: (context, error, stack) => const Text(
              'Poster tidak bisa dimuat',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }
}
