import 'dart:convert';

import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan jadwal sholat supaya bisa dibaca widget di layar utama.
///
/// ## Mengapa jadwal beberapa hari disimpan
///
/// Widget Android tidak bisa memanggil perhitungan waktu sholat milik aplikasi
/// saat aplikasi sedang tidak berjalan. Kalau hanya hari ini yang disimpan,
/// widget akan kosong setiap pagi sampai pengguna membuka aplikasi — dan widget
/// yang kosong lebih buruk daripada tidak ada widget.
///
/// Jadi jadwal [jumlahHari] hari ke depan disimpan sekaligus. Sisi Kotlin
/// memilih baris yang tanggalnya hari ini. Kalau umurnya sudah lewat, widget
/// menampilkan ajakan membuka aplikasi — bukan jam yang sudah tidak akurat.
///
/// ## Mengapa perhitungannya tetap di sini
///
/// Rumus waktu sholat memakai `adhan` dengan parameter dari
/// [NotificationService.parameterSholat]. Menuliskannya ulang di Kotlin akan
/// menciptakan dua sumber kebenaran yang bisa berbeda tanpa terlihat.
class WidgetService {
  WidgetService._();

  /// Kunci data di penyimpanan widget. Harus sama dengan yang dibaca Kotlin.
  static const String kunciJadwal = 'jadwal_sholat_json';

  /// Nama kelas Kotlin provider widget. home_widget menambahkan nama paket
  /// aplikasi secara otomatis.
  static const String namaWidgetAndroid = 'JadwalSholatWidgetProvider';

  /// Kunci data kajian terdekat.
  static const String kunciKajian = 'kajian_terdekat_json';

  /// Kelas Kotlin provider widget jadwal kajian.
  static const String namaWidgetKajianAndroid = 'JadwalKajianWidgetProvider';

  /// Pilihan pengguna: widget mana yang mau dipakai.
  ///
  /// Ada yang cukup dengan jadwal sholat, ada yang mau keduanya. Aplikasi
  /// tidak memaksa — data hanya disimpan untuk widget yang dipilih.
  static const String prefWidgetSholat = 'widget_sholat_aktif';
  static const String prefWidgetKajian = 'widget_kajian_aktif';

  /// Widget layar utama baru dibuat untuk Android.
  static bool get didukung =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Membaca pilihan pengguna.
  ///
  /// Default-nya AKTIF: pengguna yang sudah terlanjur memasang widget tidak
  /// boleh kehilangan datanya hanya karena pembaruan aplikasi.
  static Future<bool> _dipilih(String kunci) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kunci) ?? true;
  }

  /// Berapa hari ke depan disimpan.
  static const int jumlahHari = 7;

  /// Menyimpan jadwal lalu meminta widget menggambar ulang.
  ///
  /// Semua kegagalan ditelan diam-diam: widget adalah pelengkap, dan jadwal
  /// sholat di dalam aplikasi tidak boleh terganggu hanya karena widget gagal
  /// diperbarui (mis. di web atau di perangkat yang tidak mendukung).
  static Future<void> simpanJadwalSholat({
    required Coordinates koordinat,
    required CalculationParameters parameter,
    required String namaKota,
  }) async {
    if (!didukung) return;
    if (!await _dipilih(prefWidgetSholat)) return;

    try {
      final DateTime sekarang = DateTime.now();
      final List<Map<String, String>> hari = <Map<String, String>>[];

      for (int i = 0; i < jumlahHari; i++) {
        final DateTime tanggal = DateTime(
          sekarang.year,
          sekarang.month,
          sekarang.day + i,
        );

        final PrayerTimes jadwal = PrayerTimes(
          koordinat,
          DateComponents.from(tanggal),
          parameter,
        );

        hari.add(<String, String>{
          't': _tanggal(tanggal),
          // Kota disimpan PER HARI supaya jadwal tetap konsisten kalau
          // pengguna berpindah lokasi di tengah minggu.
          'kota': namaKota,
          'subuh': _jam(jadwal.fajr),
          'dzuhur': _jam(jadwal.dhuhr),
          'ashar': _jam(jadwal.asr),
          'maghrib': _jam(jadwal.maghrib),
          'isya': _jam(jadwal.isha),
        });
      }

      await HomeWidget.saveWidgetData<String>(
        kunciJadwal,
        jsonEncode(<String, dynamic>{'hari': hari}),
      );

      await HomeWidget.updateWidget(androidName: namaWidgetAndroid);
    } catch (e) {
      debugPrint('Gagal memperbarui widget jadwal sholat: $e');
    }
  }

  /// Menyimpan kajian terdekat untuk widget jadwal kajian.
  ///
  /// Memanggil tanpa argumen berarti "tidak ada kajian berikutnya". Itu
  /// disimpan secara eksplisit supaya widget tidak terus menampilkan kajian
  /// lama seolah masih akan datang.
  static Future<void> simpanKajianTerdekat({
    String? judul,
    String? waktu,
    String? ustadz,
    String? lokasi,
  }) async {
    if (!didukung) return;
    if (!await _dipilih(prefWidgetKajian)) return;

    try {
      await HomeWidget.saveWidgetData<String>(
        kunciKajian,
        jsonEncode(<String, dynamic>{
          'ada': judul != null && judul.isNotEmpty,
          'judul': judul ?? '',
          'waktu': waktu ?? '',
          'ustadz': ustadz ?? '',
          'lokasi': lokasi ?? '',
        }),
      );

      await HomeWidget.updateWidget(androidName: namaWidgetKajianAndroid);
    } catch (e) {
      debugPrint('Gagal memperbarui widget jadwal kajian: $e');
    }
  }

  /// Mengosongkan data widget jadwal sholat.
  ///
  /// Dipakai saat pengguna mematikan widget dari Pengaturan. Data lama sengaja
  /// dihapus, karena jam sholat yang sudah kedaluwarsa lebih menyesatkan
  /// daripada widget yang jujur bilang "buka aplikasi".
  static Future<void> kosongkanJadwalSholat() async {
    if (kIsWeb) return;

    try {
      await HomeWidget.saveWidgetData<String>(kunciJadwal, '');
      await HomeWidget.updateWidget(androidName: namaWidgetAndroid);
    } catch (e) {
      debugPrint('Gagal mengosongkan widget jadwal sholat: $e');
    }
  }

  /// Mengosongkan data widget jadwal kajian.
  static Future<void> kosongkanKajian() async {
    if (kIsWeb) return;

    try {
      await HomeWidget.saveWidgetData<String>(
        kunciKajian,
        jsonEncode(<String, dynamic>{
          'ada': false,
          'judul': '',
          'waktu': '',
          'ustadz': '',
          'lokasi': '',
        }),
      );

      await HomeWidget.updateWidget(androidName: namaWidgetKajianAndroid);
    } catch (e) {
      debugPrint('Gagal mengosongkan widget jadwal kajian: $e');
    }
  }

  static String _tanggal(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  static String _jam(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}
