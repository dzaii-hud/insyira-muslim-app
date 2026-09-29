import 'package:flutter/material.dart';

import '../services/streak_service.dart';
import '../theme/app_theme.dart';

/// Kartu "Runtutan Harian" — menampilkan dua runtutan terpisah:
/// 🔥 dzikir dan 📖 baca Al-Qur'an.
///
/// Bentuknya sengaja mengikuti motif yang sudah ada di aplikasi (aksen bar
/// 4×18 + judul 18 bold, kartu `cardColor` radius 16, garis `dividerColor`)
/// supaya tidak terasa sebagai tambahan yang berdiri sendiri.
class StreakCard extends StatelessWidget {
  const StreakCard({super.key, required this.ringkasan, this.padaKetuk});

  final RingkasanStreak ringkasan;

  /// Dipanggil saat salah satu runtutan ditekan. [keDzikir] `true` untuk
  /// membuka tab Dzikir, `false` untuk tab Quran.
  final void Function(bool keDzikir)? padaKetuk;

  @override
  Widget build(BuildContext context) {
    final Color emas = AppColors.getGoldLeaf(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceContainerLow(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getSurfaceVariant(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildJudul(context, emas),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _buildSatu(
                  context: context,
                  emas: emas,
                  ikon: Icons.local_fire_department_rounded,
                  judul: 'Dzikir',
                  runtutan: ringkasan.dzikir,
                  tuntasHariIni: ringkasan.dzikirHariIniTuntas,
                  keterangan: _keteranganDzikir(),
                  keDzikir: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSatu(
                  context: context,
                  emas: emas,
                  ikon: Icons.menu_book_rounded,
                  judul: 'Al-Qur\'an',
                  runtutan: ringkasan.quran,
                  tuntasHariIni: ringkasan.progresQuran.cukup,
                  keterangan: ringkasan.progresQuran.teks,
                  keDzikir: false,
                ),
              ),
            ],
          ),
          if (ringkasan.dzikir == 0 && ringkasan.quran == 0) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Belum ada runtutan. Selesaikan dzikir pagi & sore serta baca '
              'Al-Qur\'an hari ini untuk memulainya.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: AppColors.getOnSurfaceVariant(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildJudul(BuildContext context, Color emas) {
    return Row(
      children: <Widget>[
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: emas,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(Icons.whatshot_rounded, size: 17, color: emas),
        const SizedBox(width: 8),
        // ⚠️ WAJIB dibungkus Expanded. Di dalam Row, `Text` diberi lebar
        // tak terbatas sehingga TIDAK PERNAH membungkus baris — teks yang
        // lebih lebar dari sisanya akan meluber (dan itu bisa terjadi kalau
        // ukuran font sistem user diperbesar).
        Expanded(
          child: Text(
            'Runtutan Harian',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(context),
            ),
          ),
        ),
      ],
    );
  }

  /// Keterangan dzikir hari ini: mana yang sudah dan mana yang belum.
  String _keteranganDzikir() {
    if (ringkasan.dzikirHariIniTuntas) return 'pagi & sore selesai';

    final List<String> belum = <String>[
      if (!ringkasan.pagiTuntas) 'pagi',
      if (!ringkasan.soreTuntas) 'sore',
    ];
    return 'belum: ${belum.join(' & ')}';
  }

  Widget _buildSatu({
    required BuildContext context,
    required Color emas,
    required IconData ikon,
    required String judul,
    required int runtutan,
    required bool tuntasHariIni,
    required String keterangan,
    required bool keDzikir,
  }) {
    final Color warnaTeks = AppColors.getTextPrimary(context);
    final Color warnaKedua = AppColors.getOnSurfaceVariant(context);

    return InkWell(
      onTap: padaKetuk == null ? null : () => padaKetuk!(keDzikir),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          // Rata TENGAH, bukan rata kiri: dua kolom berdampingan dengan isi
          // rata kiri membuat angka besar (mis. "7") terlihat menggantung di
          // tepi kiri kolomnya.
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(ikon, size: 16, color: emas),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    judul,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: warnaKedua,
                    ),
                  ),
                ),
                if (tuntasHariIni)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: Color(0xFF4CAF50),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                // Angka runtutan bisa panjang (ratusan hari) sedangkan
                // kolomnya sempit — jadi harus boleh menyusut. Di dalam Row,
                // `Text` tidak pernah membungkus sendiri.
                Flexible(
                  child: Text(
                    '$runtutan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      height: 1,
                      color: runtutan > 0 ? warnaTeks : warnaKedua,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text('hari', style: TextStyle(fontSize: 12, color: warnaKedua)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              keterangan,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, height: 1.3, color: warnaKedua),
            ),
          ],
        ),
      ),
    );
  }
}
