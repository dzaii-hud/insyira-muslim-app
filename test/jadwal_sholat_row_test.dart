import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insyira_muslim_app/widgets/jadwal_sholat_row.dart';

/// Menguji baris lima waktu sholat pada lebar layar dan ukuran huruf yang
/// berbeda-beda.
///
/// **Latar belakang:** seorang tester memakai **Samsung Z Flip 4** dan
/// melaporkan kolom **"Isya" terpotong** di tepi kanan layar. Penyebabnya baris
/// ini memakai lima kolom berlebar tetap tanpa mekanisme menyusut.
///
/// Di build rilis, `RenderFlex` yang meluber **tidak menampilkan apa pun** —
/// isinya cuma terpotong diam-diam (di mode debug baru muncul garis kuning-hitam).
/// Karena itu tes ini memeriksa `tester.takeException()`: kalau ada overflow,
/// `pumpWidget` meninggalkan `FlutterError` dan tesnya gagal.
void main() {
  // Padang, 1 Okt 2026 — parameter sama dengan yang dipakai aplikasi.
  final PrayerTimes jadwal = PrayerTimes(
    Coordinates(-0.9471, 100.4172),
    DateComponents(2026, 10, 1),
    CalculationMethod.singapore.getParameters(),
  );

  /// Lebar layar logis (dp). 384dp = Samsung Z Flip 4, 360dp = HP kecil umum.
  const List<double> lebarLayar = <double>[320, 360, 384, 411, 480];

  /// Skala huruf sistem. 1,0 = bawaan; banyak user menaikkan ini karena
  /// penglihatan, dan Samsung punya pengaturan fontnya sendiri.
  const List<double> skalaHuruf = <double>[1.0, 1.15, 1.3, 1.5, 2.0];

  for (final double lebar in lebarLayar) {
    for (final double skala in skalaHuruf) {
      testWidgets('tidak terpotong di ${lebar.toInt()}dp dengan huruf x$skala', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = Size(lebar, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Builder(
              builder: (BuildContext context) {
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(skala)),
                  child: Scaffold(
                    body: Padding(
                      // Margin 20 seperti tata letak beranda yang asli, supaya
                      // lebar yang diuji benar-benar sama dengan di aplikasi.
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: JadwalSholatRow(waktu: jadwal, aktif: 'Maghrib'),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      });
    }
  }
}
