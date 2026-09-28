import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/responsive_content.dart';

/// Halaman **Tentang** aplikasi.
///
/// Dibuka dari sidebar / menu samping (layar lebar), dari drawer Home (HP),
/// dan dari kartu "Tentang" di halaman Pengaturan. Sebelumnya ketiga tempat
/// itu hanya menampilkan SnackBar berisi nomor versi; sekarang semuanya menuju
/// halaman ini.
///
/// Susunannya sengaja mengikuti halaman lain supaya terasa satu aplikasi:
/// * `LayoutBuilder` + [DesktopSidebarFrame] → sidebarnya tetap ada di layar
///   lebar, sementara di HP tampilannya seperti biasa (sama seperti
///   `settings_screen.dart` dan `fawaidh_screen.dart`).
/// * [ResponsiveContent] → isi halaman tidak melar di monitor lebar.
/// * Judul bagian memakai motif aksen bar 4x18 + ikon + judul 18 bold yang
///   sama dengan header section di Home / Kajian / Fawaidh.
/// * Kartu memakai `Theme.of(context).cardColor` + radius 16 + garis
///   `dividerColor`, sama seperti kartu di halaman Pengaturan.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder dipakai supaya di layar lebar sidebarnya tetap tampil
    // seperti aplikasi desktop, tanpa mengubah tampilan di HP.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints batas) {
        if (batas.maxWidth < kBreakpointDesktop) {
          return _buildHp(context);
        }
        return DesktopSidebarFrame(child: _buildHp(context));
      },
    );
  }

  /// Halaman versi HP.
  Widget _buildHp(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.getPrimaryText(context),
            size: 20,
          ),
          // `popOrHome` (bukan Navigator.pop) supaya tombolnya tetap hidup
          // kalau halaman ini dibuka langsung dari alamat /#/tentang.
          onPressed: () => popOrHome(context),
        ),
        title: Text(
          'Tentang',
          style: TextStyle(
            color: AppColors.getPrimaryText(context),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: ResponsiveContent(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _kartuIdentitas(context),
            const SizedBox(height: 24),

            // ===================== FITUR UTAMA =====================
            _judulBagian(context, 'Fitur Utama', Icons.star_outline),
            const SizedBox(height: 14),
            _kartu(
              context,
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < _daftarFitur.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: 16),
                    _barisFitur(context, _daftarFitur[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ===================== TAUTAN =====================
            _judulBagian(context, 'Tautan Resmi', Icons.link),
            const SizedBox(height: 14),
            _kartuDaftar(
              context,
              children: <Widget>[
                for (final _ItemTautan tautan in _daftarTautan)
                  ListTile(
                    onTap: () => _bukaTautan(context, tautan.alamat),
                    leading: Icon(
                      tautan.ikon,
                      color: AppColors.getGoldLeaf(context),
                    ),
                    title: Text(
                      tautan.judul,
                      style: TextStyle(
                        color: AppColors.getTextPrimary(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                    subtitle: Text(
                      tautan.keterangan,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.getOnSurfaceVariant(context),
                        fontSize: 12,
                      ),
                    ),
                    trailing: Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: AppColors.getOnSurfaceVariant(context),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // ===================== INFORMASI APLIKASI =====================
            _judulBagian(context, 'Informasi Aplikasi', Icons.info_outline),
            const SizedBox(height: 14),
            _kartu(
              context,
              child: Column(
                children: <Widget>[
                  _barisInfo(context, 'Nama aplikasi', AppInfo.nama),
                  _pemisah(context),
                  _barisInfo(context, 'Versi', AppInfo.versiLengkap),
                  _pemisah(context),
                  _barisInfo(context, 'Pengembang', AppInfo.pengembang),
                  _pemisah(context),
                  _barisInfo(
                    context,
                    'Akun',
                    'Bisa dipakai tanpa login (Mode Tamu)',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),
            _catatanKaki(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // KARTU IDENTITAS (logo + nama + versi + deskripsi)
  // =====================================================================

  Widget _kartuIdentitas(BuildContext context) {
    final Color emas = AppColors.getGoldLeaf(context);

    return _kartu(
      context,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: <Widget>[
          // Lambang aplikasi.
          //
          // Memakai ikon (bukan `logo_insyira.png`) dengan sengaja:
          // berkas logo itu 1,6 MB dan hanya dipakai untuk membuat ikon APK,
          // jadi menampilkannya di UI akan menambah unduhan besar di web.
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: emas.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: emas.withValues(alpha: 0.35)),
            ),
            child: Icon(Icons.mosque, color: emas, size: 42),
          ),
          const SizedBox(height: 16),
          Text(
            AppInfo.nama,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.getTextPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),

          // Pill versi — motif badge yang sama dengan badge di Home.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: emas.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: emas.withValues(alpha: 0.4)),
            ),
            child: Text(
              'Versi ${AppInfo.versiLengkap}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: emas,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppInfo.deskripsi,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.getOnSurfaceVariant(context),
              fontSize: 13.5,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // POTONGAN UI YANG DIPAKAI BERULANG
  // =====================================================================

  /// Judul bagian — motif yang sama dengan `_buildSectionHeader` di Home.
  Widget _judulBagian(BuildContext context, String judul, IconData ikon) {
    return Row(
      children: <Widget>[
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.getPrimaryText(context),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(ikon, size: 17, color: AppColors.getOnSurfaceVariant(context)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            judul,
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

  /// Kartu dasar: latar `cardColor`, sudut 16, garis `dividerColor`.
  ///
  /// Bentuknya sengaja identik dengan kartu di halaman Pengaturan supaya
  /// kedua halaman terlihat seragam.
  Widget _kartu(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: child,
    );
  }

  /// Kartu berisi deretan [ListTile] (dipakai untuk daftar tautan).
  ///
  /// `clipBehavior` dipasang supaya efek sentuh (riak) ikut terpotong rapi
  /// mengikuti sudut kartunya.
  Widget _kartuDaftar(BuildContext context, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  /// Satu baris fitur: ikon dalam kotak kecil + judul + keterangan.
  Widget _barisFitur(BuildContext context, _ItemFitur item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.getGoldLeaf(context).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            item.ikon,
            size: 20,
            color: AppColors.getGoldLeaf(context),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                item.judul,
                style: TextStyle(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.keterangan,
                style: TextStyle(
                  color: AppColors.getOnSurfaceVariant(context),
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Satu baris label–nilai pada kartu "Informasi Aplikasi".
  Widget _barisInfo(BuildContext context, String label, String nilai) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.getOnSurfaceVariant(context),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              nilai,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: AppColors.getTextPrimary(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pemisah(BuildContext context) {
    return Divider(height: 18, color: Theme.of(context).dividerColor);
  }

  Widget _catatanKaki(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          '© ${DateTime.now().year} ${AppInfo.pengembang}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.getOnSurfaceVariant(context),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Dibuat di Pekanbaru, Riau.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.getOnSurfaceVariant(context),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// Membuka tautan di aplikasi lain (peramban / aplikasi YouTube / surel).
  ///
  /// Kegagalan tidak dibiarkan diam: pengguna diberi tahu lewat SnackBar,
  /// pola yang sama dengan `home_screen.dart` saat membuka YouTube.
  Future<void> _bukaTautan(BuildContext context, Uri alamat) async {
    try {
      final bool berhasil = await launchUrl(
        alamat,
        mode: LaunchMode.externalApplication,
      );
      if (berhasil) return;
      throw StateError('launchUrl mengembalikan false');
    } catch (e) {
      debugPrint('Gagal membuka $alamat: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tidak dapat membuka tautan tersebut.'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
  }
}

/// Satu baris pada kartu "Fitur Utama".
class _ItemFitur {
  const _ItemFitur(this.ikon, this.judul, this.keterangan);

  final IconData ikon;
  final String judul;
  final String keterangan;
}

/// Satu baris pada kartu "Tautan Resmi".
class _ItemTautan {
  const _ItemTautan(this.ikon, this.judul, this.keterangan, this.alamat);

  final IconData ikon;
  final String judul;
  final String keterangan;
  final Uri alamat;
}

/// Daftar fitur yang ditonjolkan di halaman Tentang.
///
/// Sengaja ditulis satu per satu (bukan diambil otomatis dari
/// [kNavDestinations]) karena isinya menjelaskan *apa* fiturnya, bukan sekadar
/// daftar menu — dan tidak semua fitur punya tab sendiri.
const List<_ItemFitur> _daftarFitur = <_ItemFitur>[
  _ItemFitur(
    Icons.access_time_filled,
    'Jadwal Sholat & Adzan',
    'Waktu sholat dihitung otomatis dari lokasimu, lengkap dengan pengingat '
        'adzan.',
  ),
  _ItemFitur(
    Icons.menu_book,
    'Al-Quran',
    '114 surah, bisa dibaca dalam mode mushaf per halaman maupun mode '
        'terjemahan.',
  ),
  _ItemFitur(
    Icons.explore,
    'Arah Kiblat',
    'Kompas penunjuk arah kiblat berdasarkan posisimu saat ini.',
  ),
  _ItemFitur(
    Icons.auto_awesome,
    'Dzikir Pagi & Sore',
    'Dzikir harian beserta audionya, ditambah pengingat otomatis dua kali '
        'sehari.',
  ),
  _ItemFitur(
    Icons.calendar_month,
    'Jadwal Kajian',
    'Jadwal kajian di Musholla Insyira dan sekitarnya.',
  ),
  _ItemFitur(
    Icons.lightbulb_outline,
    'Fawaidh Asatidz',
    'Kumpulan faidah dan catatan ilmu dari para ustadz.',
  ),
  _ItemFitur(
    Icons.play_circle_outline,
    'Kajian Online',
    'Video kajian terbaru dan kabar siaran langsung dari kanal Insyira TV.',
  ),
];

/// Tautan resmi yang ditampilkan di halaman Tentang.
///
/// Semua alamatnya dibaca dari [AppInfo] supaya cukup ada SATU tempat yang
/// perlu diubah kalau alamatnya pindah. Daftarnya `final` (bukan `const`)
/// karena `Uri.parse` baru bisa dihitung saat aplikasi berjalan.
final List<_ItemTautan> _daftarTautan = <_ItemTautan>[
  _ItemTautan(
    Icons.language,
    'Situs resmi',
    'Buka versi web aplikasi ini',
    Uri.parse(AppInfo.situs),
  ),
  _ItemTautan(
    Icons.play_circle_filled,
    'Kanal YouTube Insyira TV',
    'Kajian dan siaran langsung',
    Uri.parse(AppInfo.kanalYouTube),
  ),
  _ItemTautan(
    Icons.privacy_tip_outlined,
    'Kebijakan Privasi',
    'Bagaimana data kamu diperlakukan',
    Uri.parse(AppInfo.kebijakanPrivasi),
  ),
  _ItemTautan(
    Icons.person_remove_outlined,
    'Cara Menghapus Akun',
    'Permintaan penghapusan akun dan data',
    Uri.parse(AppInfo.hapusAkun),
  ),
  _ItemTautan(
    Icons.mail_outline,
    'Hubungi Kami',
    AppInfo.email,
    Uri.parse('mailto:${AppInfo.email}'),
  ),
];
