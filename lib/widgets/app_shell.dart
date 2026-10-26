import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Satu item menu navigasi utama.
///
/// Dipakai bersama oleh menu bawah (HP) dan sidebar (layar lebar), supaya
/// keduanya tidak pernah beda urutan atau ikon.
class NavDestination {
  const NavDestination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

const List<NavDestination> kNavDestinations = <NavDestination>[
  NavDestination(icon: Icons.home_filled, label: 'Home'),
  NavDestination(icon: Icons.menu_book, label: 'Quran'),
  NavDestination(icon: Icons.explore, label: 'Qibla'),
  NavDestination(icon: Icons.calendar_month, label: 'Kajian'),
  NavDestination(icon: Icons.auto_awesome, label: 'Dzikir'),
];

/// Lebar sidebar pada layar lebar.
///
/// 250 px cukup untuk memuat label menu terpanjang tanpa terpotong, dan
/// masih menyisakan ruang lega untuk isi halaman.
const double kLebarSidebar = 250;

/// Tinggi bilah judul di atas isi halaman, khusus layar lebar.
const double kTinggiBilahJudul = 68;

/// Latar sidebar (layar lebar).
///
/// Sengaja TIDAK memakai `AppColors.getSurfaceContainerLow` yang dipakai kartu
/// (putih di mode terang). Warna itu sama dengan latar halaman yang juga
/// hampir putih, sehingga sidebar menyatu dengan isi halaman dan tampak
/// seperti bidang putih kosong tanpa bentuk.
///
/// Di mode terang sidebar diberi hijau sangat muda supaya terbaca sebagai
/// panel tersendiri — masih sejalan dengan hijau aplikasi, tidak keluar dari
/// nuansa yang sudah ada.
Color _latarSidebar(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF002117)
      : const Color(0xFFDCEBE3);
}

/// Garis pemisah antara sidebar dan isi halaman.
///
/// Dibuat lebih jelas daripada `AppColors.getSurfaceVariant` karena warna itu
/// praktis hilang di atas latar hijau muda.
Color _garisSidebar(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF003D2D)
      : const Color(0xFFB9D4C6);
}

/// Latar menu yang sedang dibuka.
///
/// Sebelumnya memakai emas tipis di atas latar putih. Hasilnya justru terlihat
/// seperti balok krem kusam — bukan penanda yang jelas. Sekarang menu terpilih
/// dibuat seperti kartu yang menonjol dari sidebar, dengan ikon emas dan
/// tulisan tebal di atasnya.
Color _latarMenuTerpilih(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF0A4635)
      : Colors.white;
}

/// Sidebar untuk layar lebar (desktop / tablet lanskap).
///
/// Bentuknya dibuat seperti aplikasi desktop: nama aplikasi di atas, daftar
/// menu dengan label di tengah, dan menu tambahan di bawah.
///
/// [selectedIndex] boleh `null` untuk halaman yang bukan salah satu tab
/// (mis. Pengaturan) — saat itu tidak ada menu yang disorot.
class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key, required this.onPilihTab, this.selectedIndex});

  /// Menu utama yang sedang dibuka, atau `null` kalau tidak ada.
  final int? selectedIndex;

  /// Dipanggil saat salah satu menu utama ditekan, dengan nomor menunya.
  final ValueChanged<int> onPilihTab;

  @override
  Widget build(BuildContext context) {
    final Color garis = _garisSidebar(context);

    // Alamat halaman yang sedang dibuka, dipakai untuk menyorot menu tambahan
    // (Pengaturan / Tentang) sama seperti menu utama menyorot tab aktif.
    final String jalurSekarang = GoRouterState.of(context).uri.path;

    return Container(
      width: kLebarSidebar,
      decoration: BoxDecoration(
        color: _latarSidebar(context),
        border: Border(right: BorderSide(color: garis)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // --- NAMA APLIKASI ---
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
            child: Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.getGoldLeaf(
                      context,
                    ).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.mosque,
                    color: AppColors.getGoldLeaf(context),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Insyira',
                        style: TextStyle(
                          color: AppColors.getTextPrimary(context),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        'Muslim App',
                        style: TextStyle(
                          color: AppColors.getOnSurfaceVariant(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: garis),

          // --- MENU UTAMA ---
          //
          // Di dalam ListView supaya tetap bisa digulir kalau nanti menunya
          // bertambah banyak atau jendela dipendekkan.
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              children: <Widget>[
                for (int i = 0; i < kNavDestinations.length; i++)
                  _BarisMenu(
                    ikon: kNavDestinations[i].icon,
                    label: kNavDestinations[i].label,
                    terpilih: selectedIndex == i,
                    onTap: () => onPilihTab(i),
                  ),
              ],
            ),
          ),

          Divider(height: 1, color: garis),

          // --- MENU TAMBAHAN ---
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              children: <Widget>[
                // Menu ini HANYA muncul untuk akun yang terdaftar sebagai ustadz.
                FutureBuilder<bool>(
                  future: AuthService().isUstadz(),
                  builder: (BuildContext context, AsyncSnapshot<bool> keadaan) {
                    if (keadaan.data != true) {
                      return const SizedBox.shrink();
                    }

                    return _BarisMenu(
                      ikon: Icons.edit_note_rounded,
                      label: 'Fawaidh Saya',
                      terpilih: jalurSekarang == AppRoutes.fawaidhSaya,
                      onTap: () => _bukaHalaman(context, AppRoutes.fawaidhSaya),
                    );
                  },
                ),
                _BarisMenu(
                  ikon: Icons.settings_outlined,
                  label: 'Pengaturan',
                  terpilih: jalurSekarang == AppRoutes.settings,
                  onTap: () => _bukaHalaman(context, AppRoutes.settings),
                ),
                _BarisMenu(
                  ikon: Icons.info_outline,
                  label: 'Tentang',
                  terpilih: jalurSekarang == AppRoutes.about,
                  onTap: () => _bukaHalaman(context, AppRoutes.about),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Membuka sebuah halaman, kecuali kalau halaman itu memang sudah terbuka
  /// (kalau tidak, halamannya menumpuk dua kali di riwayat).
  void _bukaHalaman(BuildContext context, String jalur) {
    if (GoRouterState.of(context).uri.path != jalur) {
      context.push(jalur);
    }
  }
}

/// Satu baris menu di sidebar.
class _BarisMenu extends StatelessWidget {
  const _BarisMenu({
    required this.ikon,
    required this.label,
    required this.terpilih,
    required this.onTap,
  });

  final IconData ikon;
  final String label;
  final bool terpilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color warna = terpilih
        ? AppColors.getGoldLeaf(context)
        : AppColors.getOnSurfaceVariant(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        // Menu yang sedang dibuka dibuat seperti kartu yang menonjol dari
        // sidebar — lihat [_latarMenuTerpilih]. Jauh lebih jelas daripada
        // lapisan emas tipis di atas latar putih.
        color: terpilih ? _latarMenuTerpilih(context) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: <Widget>[
                Icon(ikon, size: 22, color: warna),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: terpilih
                          ? AppColors.getTextPrimary(context)
                          : warna,
                      fontSize: 14.5,
                      fontWeight: terpilih ? FontWeight.bold : FontWeight.w500,
                    ),
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

/// Bilah judul di atas isi halaman, khusus layar lebar.
///
/// Judulnya mengikuti halaman yang sedang dibuka, jadi jelas sedang di mana.
class DesktopTopBar extends StatelessWidget {
  const DesktopTopBar({super.key, required this.judul, this.kiri, this.aksi});

  final String judul;

  /// Widget di kiri judul — biasanya tombol kembali. Boleh kosong.
  final Widget? kiri;

  /// Widget di ujung kanan bilah.
  final List<Widget>? aksi;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kTinggiBilahJudul,
      padding: EdgeInsets.only(left: kiri == null ? 24 : 6, right: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: AppColors.getSurfaceVariant(context)),
        ),
      ),
      child: Row(
        children: <Widget>[
          ?kiri,
          Expanded(
            child: Text(
              judul,
              style: TextStyle(
                color: AppColors.getTextPrimary(context),
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (aksi != null) ...aksi!,
        ],
      ),
    );
  }
}

/// Membungkus halaman yang sudah punya Scaffold sendiri dengan sidebar.
///
/// Dipakai halaman berlamat sendiri (Pengaturan, Fawaidh) supaya sidebarnya
/// tidak hilang saat berpindah dari Home. Bentuk asli halamannya tidak perlu
/// diubah — Scaffold-nya tinggal ditaruh di sebelah sidebar, dan AppBar-nya
/// otomatis jadi bilah judul untuk bagian isi.
///
/// Kelas ini HANYA dibangun saat layarnya lebar; di HP halaman tetap memakai
/// bentuk lamanya, jadi tampilan HP tidak ikut berubah.
class DesktopSidebarFrame extends StatelessWidget {
  const DesktopSidebarFrame({
    super.key,
    required this.child,
    this.selectedIndex,
  });

  final Widget child;

  /// Menu utama yang sedang aktif, atau `null` kalau tidak ada.
  final int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: <Widget>[
          AppSidebar(
            selectedIndex: selectedIndex,
            // Dari halaman lain, menekan menu utama berarti pindah ke Home
            // pada tab yang dipilih. Nomor tabnya dibawa lewat alamat, dan
            // dibaca HomeScreen saat pertama kali dibuka.
            onPilihTab: (int i) => context.go('${AppRoutes.home}?tab=$i'),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
