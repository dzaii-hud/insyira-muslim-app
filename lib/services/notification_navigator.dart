import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../router/app_router.dart';
import '../widgets/app_shell.dart';
import 'notification_service.dart';

/// Menentukan ke mana aplikasi pergi ketika sebuah notifikasi **ditekan**.
///
/// Sebelum ini, menekan notifikasi tidak melakukan apa pun: `payload` selalu
/// dikirim oleh [NotificationService], tetapi tidak ada yang membacanya.
/// Sekarang payload itu dipakai untuk membuka halaman yang bersangkutan.
///
/// Dua jalur yang harus ditangani, dan keduanya berbeda:
/// 1. Aplikasi sedang hidup (atau di latar belakang) → [tangani] dipanggil
///    lewat [NotificationService.onNotificationTap].
/// 2. Aplikasi benar-benar TERTUTUP lalu dibuka dari notifikasi → callback di
///    atas tidak terpicu sama sekali. Payload-nya hanya bisa dibaca lewat
///    `getNotificationAppLaunchDetails()`, dan itu baru mungkin setelah
///    `init()`. Untuk kasus ini [tanganiTertunda] dipanggil dari Home.
class NotificationNavigator {
  NotificationNavigator._();

  /// Nomor tab halaman Home untuk sebuah nama menu.
  ///
  /// Dicari dari [kNavDestinations], BUKAN ditulis sebagai angka, supaya
  /// menambah/menggeser menu tidak diam-diam mengarahkan notifikasi ke
  /// halaman yang salah.
  static int tabUntuk(String namaMenu) {
    final int index = kNavDestinations.indexWhere(
      (NavDestination d) => d.label == namaMenu,
    );
    return index < 0 ? 0 : index;
  }

  /// Menjalankan perintah dari sebuah payload notifikasi.
  static Future<void> tangani(String? payload) async {
    if (payload == null || payload.isEmpty) return;

    final int pemisah = payload.indexOf(':');
    final String jenis = pemisah < 0 ? payload : payload.substring(0, pemisah);
    final String nilai = pemisah < 0 ? '' : payload.substring(pemisah + 1);

    switch (jenis) {
      // Waktu sholat: panggilan adzan memang sudah berbunyi, jadi cukup buka
      // halaman utama (di sana ada hitungan waktu sholat berikutnya).
      case 'prayer':
      case 'adzan':
        await _bukaHome(0);

      // Dzikir (baik kabar selesai maupun pengingatnya) → tab Dzikir.
      case 'dzikir':
      case 'dzikir_reminder':
        await _bukaHome(tabUntuk('Dzikir'));

      // Pengingat jadwal kajian → tab Kajian, supaya user langsung melihat
      // jadwal & lokasinya.
      case 'kajian_reminder':
        await _bukaHome(tabUntuk('Kajian'));

      // Kabar siaran langsung → langsung buka videonya di YouTube.
      case 'kajian_live':
        await _bukaYouTube(nilai);

      // Pengingat runtutan: tidak punya halaman khusus, arahkan ke Home
      // supaya user melihat kartu runtutan & tombol bacanya.
      case 'streak':
        await _bukaHome(0);

      default:
        debugPrint('[Navigasi] Payload notifikasi tidak dikenal: $payload');
    }
  }

  /// Membaca payload notifikasi yang MEMBUKA aplikasi dari kondisi tertutup.
  ///
  /// Aman dipanggil kapan saja; kalau memang tidak ada, langsung kembali.
  static Future<void> tanganiTertunda() async {
    final String? payload = NotificationService().ambilPayloadPembuka();
    if (payload == null) return;
    await tangani(payload);
  }

  /// Pindah ke halaman Home sekaligus membuka tab tertentu.
  ///
  /// Memakai `navigatorKey` karena dipanggil dari luar pohon widget (bukan
  /// dari dalam sebuah halaman), jadi tidak ada `BuildContext` yang bisa
  /// dipakai.
  static Future<void> _bukaHome(int tab) async {
    final NavigatorState? navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      // Navigator belum siap (mis. aplikasi baru dibuka dan masih di splash).
      // Payload disimpan supaya bisa dicoba lagi nanti.
      debugPrint('[Navigasi] Navigator belum siap, tab $tab ditunda');
      return;
    }

    final BuildContext context = navigator.context;
    context.go('${AppRoutes.home}?tab=$tab');
  }

  /// Membuka video YouTube di aplikasi YouTube / peramban.
  static Future<void> _bukaYouTube(String videoId) async {
    if (videoId.isEmpty) return;
    final Uri url = Uri.parse('https://www.youtube.com/watch?v=$videoId');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[Navigasi] Gagal membuka $url: $e');
    }
  }
}
