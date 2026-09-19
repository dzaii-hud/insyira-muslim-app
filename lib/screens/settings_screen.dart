import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../router/app_router.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = true;
  bool _enableAzan = true;
  final NotificationService _notificationService = NotificationService();

  // ===== AKUN =====
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _user;
  bool _isLoggedIn = false;
  bool _isLoggingOut = false;

  // ===== PLAYER ADZAN MANUAL =====
  final AudioPlayer _adzanPlayer = AudioPlayer();
  bool _isAdzanPlaying = false;
  bool _isAdzanLoading = false;
  Duration _adzanDuration = Duration.zero;
  Duration _adzanPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAccount();
    _notificationService.init();
    _setupAdzanPlayer();
  }

  // ===================== AKUN & LOGOUT =====================
  Future<void> _loadAccount() async {
    final user = await _authService.getUser();
    final loggedIn = await _authService.isLoggedIn();
    if (!mounted) return;
    setState(() {
      _user = user;
      _isLoggedIn = loggedIn;
    });
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.getSurfaceContainerLow(dialogContext),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.getSurfaceVariant(dialogContext)),
        ),
        title: Text(
          'Keluar Akun',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimary(dialogContext),
          ),
        ),
        content: Text(
          'Yakin ingin keluar? Kamu masih bisa memakai aplikasi sebagai tamu.',
          style: TextStyle(
            color: AppColors.getOnSurfaceVariant(dialogContext),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Batal',
              style: TextStyle(
                color: AppColors.getOnSurfaceVariant(dialogContext),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Keluar',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoggingOut = true);
    await _authService.logout();
    if (!mounted) return;
    setState(() => _isLoggingOut = false);

    // `go` mengganti seluruh riwayat, jadi setelah keluar user tidak bisa
    // menekan Back untuk kembali ke halaman pengaturan.
    context.go(AppRoutes.login);
  }

  @override
  void dispose() {
    _adzanPlayer.dispose();
    super.dispose();
  }

  // ===================== MANUAL ADZAN PLAYER =====================
  void _setupAdzanPlayer() {
    _adzanPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _adzanDuration = d);
    });
    _adzanPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _adzanPosition = p);
    });
    _adzanPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isAdzanPlaying = state == PlayerState.playing);
      }
    });
    _adzanPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isAdzanPlaying = false;
          _adzanPosition = Duration.zero;
        });
      }
    });
  }

  Future<void> _toggleAdzanPreview() async {
    if (_isAdzanPlaying) {
      await _adzanPlayer.pause();
      return;
    }

    try {
      setState(() => _isAdzanLoading = true);

      // Kalau posisi sudah di akhir, ulangi dari awal.
      if (_adzanPosition >= _adzanDuration && _adzanDuration > Duration.zero) {
        await _adzanPlayer.stop();
      }

      if (_adzanPlayer.state == PlayerState.paused) {
        await _adzanPlayer.resume();
      } else {
        // File ada di pubspec: assets/audios/adzan.mp3
        await _adzanPlayer.play(AssetSource('audios/adzan.mp3'));
      }

      if (mounted) setState(() => _isAdzanLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAdzanLoading = false;
        _isAdzanPlaying = false;
      });
      _showSnackBar(
        'Gagal memutar adzan: file audio tidak ditemukan.',
        isSuccess: false,
      );
    }
  }

  Future<void> _stopAdzanPreview() async {
    await _adzanPlayer.stop();
    if (mounted) {
      setState(() {
        _isAdzanPlaying = false;
        _adzanPosition = Duration.zero;
      });
    }
  }

  Future<void> _testAdzanNotification() async {
    await _notificationService.ensureReady();
    final ok = await _notificationService.showTestAzan();

    if (!mounted) return;
    _showSnackBar(
      ok
          ? 'Notifikasi tes adzan dikirim. Cek notification bar HP kamu.'
          : 'Gagal mengirim notifikasi tes adzan.',
      isSuccess: ok,
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showSnackBar(String message, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess
                  ? Icons.check_circle_outline
                  : Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess
            ? const Color(0xFF003527)
            : const Color(0xFF904D00),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 100,
          left: 20,
          right: 20,
        ),
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('is_dark_mode') ?? true;
      _enableAzan = prefs.getBool('enable_azan') ?? true;
    });
  }

  Future<void> _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);

    setState(() {
      _isDarkMode = value;
    });

    // Update theme secara global pakai GlobalKey
    appKey.currentState?.updateTheme(value);

    // Tampilkan SnackBar di atas
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                value ? Icons.dark_mode : Icons.light_mode,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                value ? 'Mode Gelap diaktifkan' : 'Mode Terang diaktifkan',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          backgroundColor: value
              ? const Color(0xFF003527)
              : const Color(0xFF904D00),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 100,
            left: 20,
            right: 20,
          ),
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }
  }

  Future<void> _toggleAzan(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_azan', value);

    setState(() {
      _enableAzan = value;
    });

    if (!value) {
      await _notificationService.cancelAllNotifications();
    } else {
      // Jadwalkan ulang adzan dari jadwal sholat terakhir yang tersimpan,
      // supaya adzan langsung aktif tanpa harus buka halaman Home dulu.
      await _notificationService.rescheduleFromSavedPrayerTimes();
    }

    // Tampilkan SnackBar di atas
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                value ? Icons.notifications_active : Icons.notifications_off,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value
                      ? 'Adzan otomatis diaktifkan'
                      : 'Adzan otomatis dinonaktifkan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: value
              ? const Color(0xFF003527)
              : const Color(0xFF904D00),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 100,
            left: 20,
            right: 20,
          ),
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pengaturan',
          style: TextStyle(color: AppColors.getTextPrimary(context)),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: AppColors.getTextPrimary(context),
          ),
          onPressed: () => popOrHome(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===================== AKUN =====================
          if (_isLoggedIn && _user != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.getGoldLeaf(
                          context,
                        ).withValues(alpha: 0.18),
                        child: Text(
                          ((_user!['name'] ?? '?').toString().trim().isNotEmpty
                                  ? _user!['name'].toString().trim()[0]
                                  : '?')
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getGoldLeaf(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _user!['name']?.toString() ?? 'Pengguna',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _user!['email']?.toString() ?? '-',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.getOnSurfaceVariant(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: Theme.of(context).dividerColor),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _isLoggingOut ? null : _confirmLogout,
                      icon: _isLoggingOut
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.logout_rounded,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                      label: const Text(
                        'Keluar Akun',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    color: AppColors.getGoldLeaf(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mode Tamu',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Masuk untuk menyimpan progres ibadahmu.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.getOnSurfaceVariant(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.login),
                    child: Text(
                      'Masuk',
                      style: TextStyle(
                        color: AppColors.getGoldLeaf(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Dark Mode Toggle
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: SwitchListTile(
              title: Row(
                children: [
                  Icon(
                    _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    color: _isDarkMode
                        ? AppColors.getGoldLeaf(context)
                        : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Mode Gelap',
                    style: TextStyle(
                      color: AppColors.getTextPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                _isDarkMode ? 'Tema gelap aktif' : 'Tema terang aktif',
                style: TextStyle(
                  color: AppColors.getOnSurfaceVariant(context),
                  fontSize: 12,
                ),
              ),
              value: _isDarkMode,
              onChanged: _toggleTheme,
              activeThumbColor: AppColors.getGoldLeaf(context),
            ),
          ),

          const SizedBox(height: 16),

          // ===================== SECTION ADZAN =====================
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              children: [
                // --- Catatan khusus web: notifikasi adzan tidak didukung browser ---
                if (!NotificationService.isSupported)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.getGoldLeaf(
                        context,
                      ).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.getGoldLeaf(
                          context,
                        ).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: AppColors.getGoldLeaf(context),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Adzan otomatis hanya tersedia di aplikasi '
                            'Android/iOS. Di browser, notifikasi lokal belum '
                            'didukung.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: AppColors.getOnSurfaceVariant(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // --- Toggle adzan otomatis ---
                SwitchListTile(
                  title: Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: AppColors.getGoldLeaf(context),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Adzan Otomatis',
                        style: TextStyle(
                          color: AppColors.getTextPrimary(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    _enableAzan
                        ? 'Adzan diputar tepat saat masuk waktu sholat'
                        : 'Adzan otomatis nonaktif',
                    style: TextStyle(
                      color: AppColors.getOnSurfaceVariant(context),
                      fontSize: 12,
                    ),
                  ),
                  value: _enableAzan,
                  onChanged: NotificationService.isSupported
                      ? _toggleAzan
                      : null,
                  activeThumbColor: AppColors.getGoldLeaf(context),
                ),

                Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor,
                  indent: 16,
                  endIndent: 16,
                ),

                // --- Dengarkan adzan manual ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.volume_up_rounded,
                            color: AppColors.getGoldLeaf(context),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Dengarkan Adzan',
                              style: TextStyle(
                                color: AppColors.getTextPrimary(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Putar suara adzan sekarang (tanpa menunggu waktu sholat) '
                        'untuk memastikan volume HP kamu sudah pas.',
                        style: TextStyle(
                          color: AppColors.getOnSurfaceVariant(context),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Progress bar
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                        ),
                        child: Slider(
                          value: _adzanPosition.inMilliseconds.toDouble().clamp(
                            0,
                            _adzanDuration.inMilliseconds.toDouble() > 0
                                ? _adzanDuration.inMilliseconds.toDouble()
                                : 1,
                          ),
                          min: 0,
                          max: _adzanDuration.inMilliseconds.toDouble() > 0
                              ? _adzanDuration.inMilliseconds.toDouble()
                              : 1,
                          activeColor: AppColors.getGoldLeaf(context),
                          inactiveColor: Theme.of(context).dividerColor,
                          onChanged: (v) => _adzanPlayer.seek(
                            Duration(milliseconds: v.toInt()),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _fmt(_adzanPosition),
                              style: TextStyle(
                                color: AppColors.getOnSurfaceVariant(context),
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              _fmt(_adzanDuration),
                              style: TextStyle(
                                color: AppColors.getOnSurfaceVariant(context),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tombol play / stop
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.getGoldLeaf(context),
                                foregroundColor: const Color(0xFF00120B),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _isAdzanLoading
                                  ? null
                                  : _toggleAdzanPreview,
                              icon: _isAdzanLoading
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: const Color(0xFF00120B),
                                      ),
                                    )
                                  : Icon(
                                      _isAdzanPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 20,
                                    ),
                              label: Text(
                                _isAdzanPlaying ? 'Jeda' : 'Putar Adzan',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          if (_isAdzanPlaying ||
                              _adzanPosition > Duration.zero) ...[
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.getPrimaryText(
                                  context,
                                ),
                                side: BorderSide(
                                  color: Theme.of(context).dividerColor,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _stopAdzanPreview,
                              icon: const Icon(Icons.stop_rounded, size: 18),
                              label: const Text(
                                'Stop',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor,
                  indent: 16,
                  endIndent: 16,
                ),

                // --- Tes notifikasi adzan ---
                ListTile(
                  onTap: _testAdzanNotification,
                  leading: Icon(
                    Icons.notification_add_outlined,
                    color: AppColors.getGoldLeaf(context),
                  ),
                  title: Text(
                    'Tes Notifikasi Adzan',
                    style: TextStyle(
                      color: AppColors.getTextPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Kirim notifikasi adzan sekarang untuk mengecek '
                    'suara & izin notifikasi',
                    style: TextStyle(
                      color: AppColors.getOnSurfaceVariant(context),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.getOnSurfaceVariant(context),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tentang',
                  style: TextStyle(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Insyira Muslim App v1.0.0\nAplikasi panduan ibadah sehari-hari',
                  style: TextStyle(
                    color: AppColors.getOnSurfaceVariant(context),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
