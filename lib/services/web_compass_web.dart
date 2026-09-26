/// Kompas untuk peramban HP (WEB).
///
/// Kenapa perlu berkas ini: paket `flutter_compass` **tidak punya
/// implementasi web**, sehingga fitur arah kiblat mati total di browser.
/// Manajer meminta fitur kiblat tetap bisa dipakai di web asalkan diakses
/// dari HP, jadi sensor dibaca langsung dari API peramban:
/// `window.DeviceOrientationEvent` (`deviceorientation` /
/// `deviceorientationabsolute`), plus `webkitCompassHeading` milik Safari.
///
/// Catatan penting:
/// - **Android (Chrome)** mengirim event `deviceorientationabsolute` yang
///   nilainya sudah mengacu ke utara bumi. Ini sumber paling akurat dan
///   dipakai lebih dulu.
/// - **iOS Safari 13+** mewajibkan `DeviceOrientationEvent.requestPermission()`
///   yang HARUS dipanggil dari aksi user (mis. tekan tombol). Safari juga
///   menyediakan `webkitCompassHeading` yang sudah berupa arah kompas.
/// - Di laptop/PC tidak ada magnetometer. Karena itu [perambanHp] dipakai
///   `qibla_screen.dart` untuk menentukan apakah fitur ini ditampilkan.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

class WebCompass {
  const WebCompass._();

  static final StreamController<double> _pengendali =
      StreamController<double>.broadcast();

  static bool _terpasang = false;
  static bool _dapatSumberAbsolut = false;
  static double? _terakhir;

  /// Arah terakhir yang diketahui (derajat, 0 = Utara). Null kalau belum ada.
  static double? get arahTerakhir => _terakhir;

  /// Apakah peramban ini menyediakan API sensor orientasi.
  static bool get tersedia => _konstruktor != null;

  /// Apakah halaman sedang dibuka dari peramban HP — bukan laptop/PC.
  ///
  /// Dipakai supaya penunjuk arah kiblat hanya muncul di HP (permintaan
  /// manajer). Selain nama perangkat, "mobile" juga dikenali supaya peramban
  /// HP yang menyamarkan namanya tetap terdeteksi.
  static bool get perambanHp {
    final String ua = web.window.navigator.userAgent.toLowerCase();
    return ua.contains('android') ||
        ua.contains('iphone') ||
        ua.contains('ipod') ||
        ua.contains('ipad') ||
        ua.contains('mobile');
  }

  /// Apakah sensor butuh izin user (iOS 13+).
  static bool get perluIzin {
    final JSObject? ctor = _konstruktor;
    if (ctor == null) return false;
    return ctor.has('requestPermission');
  }

  /// Meminta izin sensor.
  ///
  /// ⚠️ WAJIB dipanggil dari aksi user (tekan tombol). Kalau dipanggil
  /// otomatis saat halaman dibuka, iOS akan menolaknya dan izinnya tidak
  /// akan pernah muncul lagi.
  static Future<bool> mintaIzin() async {
    if (!perluIzin) return true;
    try {
      final JSObject ctor = _konstruktor!;
      final JSPromise<JSString> janji = ctor.callMethod<JSPromise<JSString>>(
        'requestPermission'.toJS,
      );
      final String status = (await janji.toDart).toDart;
      return status == 'granted';
    } catch (e) {
      return false;
    }
  }

  /// Aliran arah kompas (derajat, 0 = Utara, searah jarum jam).
  ///
  /// Mengembalikan `null` kalau peramban tidak mendukung sama sekali.
  static Stream<double>? get aliran {
    if (!tersedia) return null;
    _pasang();
    return _pengendali.stream;
  }

  // ===================== INTERNAL =====================

  /// Objek global `DeviceOrientationEvent` (berfungsi juga sebagai penanda
  /// bahwa API-nya memang ada di peramban ini).
  static JSObject? get _konstruktor =>
      _objek(web.window['DeviceOrientationEvent']);

  static void _pasang() {
    if (_terpasang) return;
    _terpasang = true;
    _dengar('deviceorientationabsolute', absolut: true);
    _dengar('deviceorientation', absolut: false);
  }

  static void _dengar(String jenis, {required bool absolut}) {
    web.window.addEventListener(
      jenis,
      ((JSObject event) {
        // Begitu sumber absolut tersedia, event biasa tidak dipakai lagi
        // karena nilainya bisa relatif terhadap arah awal perangkat —
        // kompasnya akan melompat-lompat.
        if (absolut) {
          _dapatSumberAbsolut = true;
        } else if (_dapatSumberAbsolut) {
          return;
        }

        final double? arah = _arahDariEvent(event, absolut: absolut);
        if (arah == null) return;

        _terakhir = arah;
        if (!_pengendali.isClosed) _pengendali.add(arah);
      }).toJS,
    );
  }

  /// Mengubah event orientasi menjadi arah kompas 0–360.
  static double? _arahDariEvent(JSObject event, {required bool absolut}) {
    // iOS Safari sudah menyediakan arah kompas sebenarnya.
    final double? arahIos = _angka(event['webkitCompassHeading']);
    if (arahIos != null) return _normalisasi(arahIos);

    if (!absolut) {
      // Tanpa penanda `absolute: true`, nilai `alpha` pada beberapa perangkat
      // bukanlah arah utara — lebih baik tidak dipakai daripada menyesatkan.
      final JSAny? penanda = event['absolute'];
      final bool sudahAbsolut =
          penanda != null &&
          penanda.isA<JSBoolean>() &&
          (penanda as JSBoolean).toDart;
      if (!sudahAbsolut) return null;
    }

    final double? alpha = _angka(event['alpha']);
    if (alpha == null) return null;

    // `alpha` bertambah berlawanan arah jarum jam, sedangkan arah kompas
    // searah jarum jam — makanya dibalik. Sudut layar ikut ditambahkan supaya
    // arahnya tetap benar saat HP dimiringkan (mode lanskap).
    return _normalisasi(360 - alpha + _sudutLayar());
  }

  /// Rotasi layar dalam derajat (0 / 90 / 180 / 270).
  static double _sudutLayar() {
    try {
      final JSObject? orientasi = _objek(
        _objek(web.window['screen'])?['orientation'],
      );
      if (orientasi != null) {
        return _angka(orientasi['angle']) ?? 0;
      }
      // Peramban lama memakai `window.orientation`.
      return _angka(web.window['orientation']) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Membalik nilai JSAny menjadi [JSObject] kalau memang sebuah objek.
  static JSObject? _objek(JSAny? nilai) {
    if (nilai == null || nilai.isUndefinedOrNull) return null;
    if (!nilai.isA<JSObject>()) return null;
    return nilai as JSObject;
  }

  /// Membalik nilai JSAny menjadi angka, kalau memang angka.
  static double? _angka(JSAny? nilai) {
    if (nilai == null || nilai.isUndefinedOrNull) return null;
    if (!nilai.isA<JSNumber>()) return null;
    final double hasil = (nilai as JSNumber).toDartDouble;
    return hasil.isNaN ? null : hasil;
  }

  static double _normalisasi(double derajat) {
    final double d = derajat % 360;
    return d < 0 ? d + 360 : d;
  }
}
