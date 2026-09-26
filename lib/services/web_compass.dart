/// Pemilih implementasi kompas peramban.
///
/// - Saat aplikasi dibangun untuk WEB, berkas `web_compass_web.dart` dipakai
///   (membaca event `deviceorientation` peramban).
/// - Saat dibangun untuk Android/iOS, `web_compass_stub.dart` yang dipakai —
///   isinya kosong supaya kode web tidak ikut masuk ke APK.
///
/// Cara pakai: `import '../services/web_compass.dart';` lalu akses
/// `WebCompass.aliran`, `WebCompass.perambanHp`, dan seterusnya.
///
/// ⚠️ Pemilih ini memakai `dart.library.js_interop` (BUKAN `dart.library.html`)
/// karena sejak Dart 3.3+ itulah penanda bahwa kode yang dikompilasi adalah
/// kode web.
library;

export 'web_compass_stub.dart'
    if (dart.library.js_interop) 'web_compass_web.dart';
