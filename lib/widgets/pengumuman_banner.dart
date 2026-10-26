import 'package:flutter/material.dart';

import '../services/pengumuman_service.dart';
import '../theme/app_theme.dart';

/// Pengumuman dari pengurus, tampil di beranda.
///
/// Dua bentuk, dan sengaja dibedakan:
///
/// 1. **Dialog sekali saja** — muncul pertama kali pengumuman itu dilihat.
///    Id pengumuman yang sudah dilihat disimpan, jadi tidak berulang setiap
///    aplikasi dibuka. Kalau pengurus menulis pengumuman baru, dialognya
///    muncul lagi.
///
/// 2. **Kartu kecil yang menetap** — selama pengumumannya masih tayang.
///    Ini yang mengingatkan tanpa memaksa: bisa diabaikan, tapi tetap
///    terlihat. Pengurus mematikannya sendiri dari panel admin kalau sudah
///    tidak perlu.
///
/// Widget ini mengurus pengambilannya sendiri supaya beranda tidak perlu
/// menambah variabel dan pemanggilan jaringan hanya untuk satu pesan.
class PengumumanBanner extends StatefulWidget {
  const PengumumanBanner({super.key});

  @override
  State<PengumumanBanner> createState() => _PengumumanBannerState();
}

class _PengumumanBannerState extends State<PengumumanBanner> {
  Pengumuman? _pengumuman;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final Pengumuman? pengumuman = await PengumumanService.ambil();

    if (!mounted || pengumuman == null) return;

    setState(() => _pengumuman = pengumuman);

    // Dialog hanya sekali per pengumuman. Ditandai SETELAH dialog ditutup,
    // supaya kalau aplikasi ditutup paksa saat dialog terbuka, pengumumannya
    // masih muncul lagi di kesempatan berikutnya.
    if (await PengumumanService.perluDiberitahu(pengumuman.id)) {
      if (!mounted) return;
      await _bukaDialog(pengumuman);
      await PengumumanService.tandaiSudahDibaca(pengumuman.id);
    }
  }

  Future<void> _bukaDialog(Pengumuman pengumuman) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: Icon(
            Icons.campaign_rounded,
            color: AppColors.getGoldLeaf(dialogContext),
            size: 28,
          ),
          title: Text(
            pengumuman.judul,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.getTextPrimary(dialogContext),
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              pengumuman.isi,
              style: TextStyle(
                color: AppColors.getOnSurfaceVariant(dialogContext),
                fontSize: 13.5,
                height: 1.65,
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Baik, mengerti'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Pengumuman? pengumuman = _pengumuman;

    // Ruang bawah hanya dipakai kalau kartunya benar-benar tampil, supaya
    // jarak antar-bagian beranda tetap sama saat tidak ada pengumuman.
    if (pengumuman == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Material(
        color: AppColors.getSurfaceVariant(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (pengumuman.id > 0) _bukaDialog(pengumuman);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.campaign_rounded,
                    size: 19,
                    color: AppColors.getGoldLeaf(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        pengumuman.judul,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.getTextPrimary(context),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        pengumuman.isi,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.getOnSurfaceVariant(context),
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.getOnSurfaceVariant(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
