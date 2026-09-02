import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = true;
  bool _enableAzan = true;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _notificationService.init();
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
              Text(
                value
                    ? 'Notifikasi azan diaktifkan'
                    : 'Notifikasi azan dinonaktifkan',
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
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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

          // Azan Notification Toggle
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
                    Icons.notifications_active,
                    color: AppColors.getGoldLeaf(context),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Notifikasi Azan',
                    style: TextStyle(
                      color: AppColors.getTextPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                _enableAzan
                    ? 'Notifikasi waktu sholat aktif'
                    : 'Notifikasi nonaktif',
                style: TextStyle(
                  color: AppColors.getOnSurfaceVariant(context),
                  fontSize: 12,
                ),
              ),
              value: _enableAzan,
              onChanged: _toggleAzan,
              activeThumbColor: AppColors.getGoldLeaf(context),
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
