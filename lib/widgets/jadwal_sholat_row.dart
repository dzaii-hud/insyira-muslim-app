import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

/// Baris lima waktu sholat di bawah kartu "Shalat Selanjutnya" pada beranda.
///
/// Dipisah dari `home_screen.dart` supaya bisa diuji sendiri. Alasannya nyata:
/// seorang tester (Samsung Z Flip 4) melaporkan kolom **"Isya" terpotong** di
/// tepi kanan layar. Versi lama memakai lima kolom berlebar tetap, sehingga
/// begitu layar sempit atau huruf sistem user dibesarkan, isinya meluber ke
/// luar layar **tanpa pesan apa pun** (di build rilis hanya terpotong diam-diam).
///
/// Sekarang setiap kolom dibagi rata (`Expanded`) dan isinya boleh mengecil
/// (`FittedBox`) — jadi tidak mungkin meluber lagi. Dijaga oleh
/// `test/jadwal_sholat_row_test.dart` yang menyapu lebar 320-480dp dikali skala
/// huruf 1,0-2,0.
class JadwalSholatRow extends StatelessWidget {
  const JadwalSholatRow({super.key, required this.waktu, this.aktif});

  /// Jadwal sholat hari ini. Kalau `null`, semua kolom menampilkan `--:--`.
  final PrayerTimes? waktu;

  /// Nama waktu sholat yang sedang aktif ("Subuh", "Maghrib", dst) — kolomnya
  /// diberi latar dan warna emas.
  final String? aktif;

  @override
  Widget build(BuildContext context) {
    final List<_ItemJadwal> daftar = <_ItemJadwal>[
      _ItemJadwal('Subuh', _jam(waktu?.fajr)),
      _ItemJadwal('Dzuhur', _jam(waktu?.dhuhr)),
      _ItemJadwal('Ashar', _jam(waktu?.asr)),
      _ItemJadwal('Maghrib', _jam(waktu?.maghrib)),
      _ItemJadwal('Isya', _jam(waktu?.isha)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      child: Row(
        children: <Widget>[
          for (final _ItemJadwal item in daftar)
            // Expanded: lima kolom dibagi rata, jadi tidak ada kolom yang bisa
            // mengambil lebih dari jatahnya. Center: isinya tetap rapat dan
            // berada di tengah jatahnya, seperti `spaceAround` yang lama.
            Expanded(
              child: Center(
                child: _KolomWaktu(
                  nama: item.nama,
                  jam: item.jam,
                  aktif: item.nama == aktif,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Jam `HH:mm`, atau `--:--` selama jadwalnya belum ada.
  static String _jam(DateTime? w) =>
      w == null ? '--:--' : DateFormat('HH:mm').format(w);
}

/// Satu nama waktu sholat, dipakai internal oleh [JadwalSholatRow].
class _ItemJadwal {
  const _ItemJadwal(this.nama, this.jam);

  final String nama;
  final String jam;
}

/// Satu kolom waktu sholat (nama di atas, jam di bawah).
class _KolomWaktu extends StatelessWidget {
  const _KolomWaktu({
    required this.nama,
    required this.jam,
    required this.aktif,
  });

  final String nama;
  final String jam;
  final bool aktif;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Padding horizontalnya kecil: ruangnya dipakai untuk MENAMPUNG teks,
      // bukan untuk mendorong tepi kartu.
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: aktif
            ? AppColors.getSurfaceVariant(context)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      // FittedBox: kalau jatah lebar kolom sempit atau huruf sistem user
      // dibesarkan, isi kolom MENGECIL sendiri. Inilah yang menghentikan
      // kolom "Isya" terpotong di tepi layar.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          children: <Widget>[
            Text(
              nama,
              style: TextStyle(
                color: aktif
                    ? AppColors.getGoldLeaf(context)
                    : AppColors.getOnSurfaceVariant(context),
                fontSize: 12,
                fontWeight: aktif ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              jam,
              style: TextStyle(
                color: aktif
                    ? AppColors.getGoldLeaf(context)
                    : AppColors.getTextPrimary(context),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
