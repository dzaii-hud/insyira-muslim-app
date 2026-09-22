import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/notification_service.dart';
import '../services/youtube_service.dart';
import '../theme/app_theme.dart';

/// Panel notifikasi yang dibuka dari ikon lonceng di sudut kanan atas.
///
/// Isinya sengaja **bukan** daftar riwayat notifikasi (Android tidak
/// menyediakan API untuk membaca riwayat notifikasi aplikasi sendiri).
/// Yang ditampilkan adalah hal-hal yang memang bisa dipastikan aplikasi:
///
/// 1. **Semua notifikasi adzan hari ini** — nama waktu, jam, dan statusnya
///    (sudah lewat / berikutnya beserta hitung mundur), dibaca dari jadwal
///    sholat terakhir yang tersimpan di perangkat.
/// 2. **Kabar kajian live** — diperiksa langsung ke backend saat panel dibuka,
///    jadi kabar yang tampil selalu yang terbaru.
///
/// Cara memakai:
/// ```dart
/// await showNotificationCenter(context);
/// ```
Future<void> showNotificationCenter(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) => const NotificationCenterSheet(),
  );
}

class NotificationCenterSheet extends StatefulWidget {
  const NotificationCenterSheet({super.key});

  @override
  State<NotificationCenterSheet> createState() =>
      _NotificationCenterSheetState();
}

class _NotificationCenterSheetState extends State<NotificationCenterSheet> {
  final NotificationService _notificationService = NotificationService();
  final YouTubeService _youtubeService = YouTubeService();

  bool _memuat = true;
  Map<String, DateTime> _jadwalAdzan = <String, DateTime>{};
  bool _adzanAktif = true;

  List<YouTubeVideo> _liveVideos = <YouTubeVideo>[];
  String _errorLive = '';

  @override
  void initState() {
    super.initState();
    _muatData();
  }

  Future<void> _muatData() async {
    // Adzan dibaca dari perangkat (cepat), kabar live dari server.
    final jadwal = await _notificationService.getSavedPrayerTimes();
    final aktif = await _notificationService.isAzanEnabled();

    if (mounted) {
      setState(() {
        _jadwalAdzan = jadwal;
        _adzanAktif = aktif;
      });
    }

    try {
      final live = await _youtubeService.getLiveVideos();
      if (mounted) {
        setState(() {
          _liveVideos = live;
          _errorLive = '';
          _memuat = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorLive = 'Tidak bisa menghubungi server';
          _memuat = false;
        });
      }
    }
  }

  Future<void> _bukaVideo(YouTubeVideo video) async {
    final id = video.id.trim();
    final Uri url = id.isEmpty
        ? Uri.parse('https://www.youtube.com/channel/UCxYY8T_y2mAgQQCjYvWwZdw')
        : Uri.parse('https://www.youtube.com/watch?v=$id');

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka YouTube')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final warnaKartu = AppColors.getSurfaceContainerLow(context);
    final warnaTeks = AppColors.getTextPrimary(context);
    final warnaRedup = AppColors.getOnSurfaceVariant(context);
    final warnaEmas = AppColors.getGoldLeaf(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: warnaRedup.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.notifications_active,
                      color: warnaEmas,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Notifikasi',
                            style: TextStyle(
                              color: warnaTeks,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            DateFormat(
                              'EEEE, d MMMM y',
                              'id_ID',
                            ).format(DateTime.now()),
                            style: TextStyle(color: warnaRedup, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      icon: Icon(Icons.close, color: warnaRedup),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  children: <Widget>[
                    _judulBagian(
                      'Notifikasi Adzan',
                      Icons.mosque,
                      warnaTeks,
                      warnaEmas,
                    ),
                    const SizedBox(height: 10),
                    _kartuAdzan(warnaKartu, warnaTeks, warnaRedup, warnaEmas),
                    const SizedBox(height: 22),
                    _judulBagian(
                      'Kajian Live',
                      Icons.podcasts,
                      warnaTeks,
                      warnaEmas,
                    ),
                    const SizedBox(height: 10),
                    _kartuKajianLive(
                      warnaKartu,
                      warnaTeks,
                      warnaRedup,
                      warnaEmas,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _judulBagian(
    String teks,
    IconData ikon,
    Color warnaTeks,
    Color warnaEmas,
  ) {
    return Row(
      children: <Widget>[
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: warnaEmas,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(ikon, size: 18, color: warnaEmas),
        const SizedBox(width: 8),
        Text(
          teks,
          style: TextStyle(
            color: warnaTeks,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _kartuAdzan(
    Color warnaKartu,
    Color warnaTeks,
    Color warnaRedup,
    Color warnaEmas,
  ) {
    if (_jadwalAdzan.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: warnaKartu,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Jadwal adzan belum tersimpan',
              style: TextStyle(
                color: warnaTeks,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Izinkan akses lokasi, lalu buka tab Home sekali. Setelah itu '
              'semua waktu adzan akan muncul di sini dan tetap berbunyi '
              'walau aplikasi ditutup.',
              style: TextStyle(color: warnaRedup, fontSize: 12.5, height: 1.5),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final daftar = _jadwalAdzan.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Waktu sholat berikutnya = yang jamnya masih di depan.
    // Sengaja tanpa `firstOrNull` supaya tidak bergantung pada paket
    // `collection` — proyek ini tidak memasukkannya sebagai dependensi.
    MapEntry<String, DateTime>? berikutnya;
    for (final entry in daftar) {
      if (entry.value.isAfter(now)) {
        berikutnya = entry;
        break;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: warnaKartu,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          if (!_adzanAktif)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.14),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Adzan otomatis sedang dimatikan. Nyalakan kembali di '
                      'Pengaturan agar adzan berbunyi.',
                      style: TextStyle(color: warnaTeks, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ...daftar.map((e) {
            final sudahLewat = e.value.isBefore(now);
            final iniBerikutnya = berikutnya != null && e.key == berikutnya.key;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: <Widget>[
                  Icon(
                    sudahLewat
                        ? Icons.notifications_off_outlined
                        : Icons.notifications_active_outlined,
                    size: 20,
                    color: sudahLewat ? warnaRedup : warnaEmas,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      e.key,
                      style: TextStyle(
                        color: warnaTeks,
                        fontSize: 14.5,
                        fontWeight: iniBerikutnya
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    DateFormat('HH:mm').format(e.value),
                    style: TextStyle(
                      color: warnaTeks,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _lencanaStatus(
                    sudahLewat: sudahLewat,
                    iniBerikutnya: iniBerikutnya,
                    adzanAktif: _adzanAktif,
                    warnaEmas: warnaEmas,
                    warnaRedup: warnaRedup,
                  ),
                ],
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Row(
              children: <Widget>[
                Icon(Icons.info_outline, size: 15, color: warnaRedup),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _adzanAktif
                        ? 'Semua waktu di atas otomatis berbunyi sebagai '
                              'notifikasi suara adzan, tiap hari, tanpa perlu '
                              'membuka aplikasi.'
                        : 'Jadwal di atas tidak akan berbunyi sampai adzan '
                              'dinyalakan lagi di Pengaturan.',
                    style: TextStyle(
                      color: warnaRedup,
                      fontSize: 11.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lencanaStatus({
    required bool sudahLewat,
    required bool iniBerikutnya,
    required bool adzanAktif,
    required Color warnaEmas,
    required Color warnaRedup,
  }) {
    final bool ditonjolkan = iniBerikutnya && adzanAktif;

    final String teks = !adzanAktif
        ? 'Nonaktif'
        : sudahLewat
        ? 'Sudah lewat'
        : iniBerikutnya
        ? 'Berikutnya'
        : 'Terjadwal';

    final Color warna = ditonjolkan
        ? warnaEmas
        : sudahLewat
        ? warnaRedup.withOpacity(0.75)
        : warnaRedup;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: warna.withOpacity(ditonjolkan ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        teks,
        style: TextStyle(
          color: warna,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _kartuKajianLive(
    Color warnaKartu,
    Color warnaTeks,
    Color warnaRedup,
    Color warnaEmas,
  ) {
    if (_memuat) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: warnaKartu,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(warnaEmas),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Memeriksa siaran live...',
              style: TextStyle(color: warnaRedup, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorLive.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: warnaKartu,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.cloud_off, color: warnaRedup, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$_errorLive. Periksa koneksi internetmu, lalu buka panel ini lagi.',
                style: TextStyle(
                  color: warnaRedup,
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Ada siaran live.
    if (_liveVideos.isNotEmpty) {
      final video = _liveVideos.first;
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: warnaKartu,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SEDANG LIVE',
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    video.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: warnaTeks,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video.channelTitle,
                    style: TextStyle(color: warnaRedup, fontSize: 11.5),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _bukaVideo(video),
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text('Tonton Sekarang'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Tidak ada siaran live.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: warnaKartu,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.videocam_off_outlined, color: warnaRedup, size: 20),
              const SizedBox(width: 10),
              Text(
                'Belum ada kajian live',
                style: TextStyle(
                  color: warnaTeks,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Kamu akan otomatis dapat notifikasi begitu Insyira TV mulai '
            'menyiarkan kajian, asalkan aplikasi pernah dibuka dalam ~15 menit '
            'terakhir.',
            style: TextStyle(color: warnaRedup, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}
