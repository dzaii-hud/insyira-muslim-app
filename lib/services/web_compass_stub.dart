/// Versi NON-WEB dari [WebCompass].
///
/// Berkas ini hanya dipakai saat aplikasi dibangun untuk Android/iOS. Tidak
/// boleh menyentuh API peramban sama sekali — kalau menyentuh, build Android
/// akan gagal. Di Android/iOS sensor kompas dibaca lewat `flutter_compass`
/// (`FlutterCompass.events`) di `qibla_screen.dart`.
library;

import 'dart:async';

class WebCompass {
  const WebCompass._();

  /// Sensor kompas peramban tidak berlaku di sini.
  static bool get tersedia => false;

  /// Bukan peramban HP.
  static bool get perambanHp => false;

  /// Tidak ada izin yang perlu diminta.
  static bool get perluIzin => false;

  static Future<bool> mintaIzin() async => false;

  /// Tidak ada aliran data.
  static Stream<double>? get aliran => null;

  /// Tidak ada arah terakhir.
  static double? get arahTerakhir => null;
}
