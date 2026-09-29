import 'package:flutter/material.dart';

import '../services/streak_service.dart';
import '../theme/app_theme.dart';

/// Kartu runtutan bergaya **bulatan per-hari** untuk halaman Quran & Dzikir.
///
/// Bentuknya berbeda dari kartu [StreakCard] di halaman utama (yang hanya
/// menampilkan angka). Di sini tiap hari dalam minggu berjalan punya satu
/// bulatan, jadi user bisa langsung melihat hari mana yang bolong — bukan
/// cuma panjang runtutannya.
///
/// Tiga keadaan bulatan:
/// * **tuntas** → biru + centang
/// * **hari ini, belum tuntas** → oranye polos (menarik perhatian, tanpa
///   centang karena memang belum dikerjakan)
/// * belum tuntas / belum terjadi → abu-abu muda polos
class StreakWeekCard extends StatelessWidget {
  const StreakWeekCard({
    super.key,
    required this.judul,
    required this.ikon,
    required this.runtutan,
    required this.tanggalTuntas,
    required this.tuntasHariIni,
    required this.keteranganHariIni,
    this.terang = false,
    this.sekarang,
  });

  final String judul;
  final IconData ikon;

  /// Panjang runtutan yang masih berlaku.
  final int runtutan;

  /// Tanggal (`yyyy-MM-dd`) yang pernah tuntas, dari [RingkasanStreak].
  final Set<String> tanggalTuntas;

  final bool tuntasHariIni;

  /// Satu baris penjelas keadaan hari ini, mis. `belum: sore` atau `4/10 ayat`.
  final String keteranganHariIni;

  /// `true` = pakai warna terang yang dipatok (untuk halaman Quran, yang
  /// memang SELALU terang dan tidak mengikuti mode gelap). `false` = mengikuti
  /// tema aplikasi (untuk halaman Dzikir).
  ///
  /// Dipisah begini karena warna halaman Quran sengaja tidak mengikuti tema —
  /// kalau kartu ini memakai [AppColors], kartunya jadi gelap di tengah halaman
  /// terang.
  final bool terang;

  /// Dipakai tes supaya "hari ini" bisa dipatok. Bawaan: waktu sekarang.
  final DateTime? sekarang;

  static const Color _biru = Color(0xFF29B6F6);
  static const Color _oranye = Color(0xFFF5A623);

  @override
  Widget build(BuildContext context) {
    final DateTime saat = sekarang ?? DateTime.now();
    final List<HariStreak> minggu = StreakService.mingguIni(
      sekarang: saat,
      tanggalTuntas: tanggalTuntas,
    );

    final Color warnaKartu = terang
        ? Colors.white
        : AppColors.getSurfaceContainerLow(context);
    final Color warnaGaris = terang
        ? const Color(0xFFE3E5E6)
        : AppColors.getSurfaceVariant(context);
    final Color warnaTeks = terang
        ? const Color(0xFF191C1D)
        : AppColors.getTextPrimary(context);
    final Color warnaKedua = terang
        ? const Color(0xFF707974)
        : AppColors.getOnSurfaceVariant(context);
    final Color warnaAksen = terang
        ? const Color(0xFF003527)
        : AppColors.getGoldLeaf(context);
    final Color warnaKosong = terang
        ? const Color(0xFFE8EAEB)
        : AppColors.getSurfaceVariant(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: warnaKartu,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warnaGaris),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(ikon, size: 18, color: warnaAksen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  judul,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: warnaTeks,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: warnaAksen.withValues(alpha: terang ? 0.08 : 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$runtutan hari',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: warnaAksen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tujuh bulatan minggu berjalan. Sengaja memakai Row + Expanded
          // (bukan daftar menggulir) supaya seluruh minggu selalu terlihat
          // sekaligus di lebar layar HP sekecil apa pun.
          Row(
            children: <Widget>[
              for (final HariStreak h in minggu)
                Expanded(
                  child: _buildHari(
                    hari: h,
                    warnaKosong: warnaKosong,
                    warnaKedua: warnaKedua,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Icon(
                tuntasHariIni
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                size: 15,
                color: tuntasHariIni ? const Color(0xFF4CAF50) : warnaKedua,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  keteranganHariIni,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.3,
                    color: warnaKedua,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHari({
    required HariStreak hari,
    required Color warnaKosong,
    required Color warnaKedua,
  }) {
    final Color isi = hari.tuntas
        ? _biru
        : (hari.hariIni ? _oranye : warnaKosong);

    return Column(
      children: <Widget>[
        Text(
          hari.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: hari.hariIni ? FontWeight.w700 : FontWeight.w500,
            color: hari.hariIni ? _oranye : warnaKedua,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isi,
            shape: BoxShape.circle,
            border: hari.masaDepan
                ? Border.all(color: warnaKedua.withValues(alpha: 0.35))
                : null,
          ),
          child: hari.tuntas
              ? const Icon(Icons.check_rounded, size: 19, color: Colors.white)
              : null,
        ),
      ],
    );
  }
}
