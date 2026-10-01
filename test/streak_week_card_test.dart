import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insyira_muslim_app/widgets/streak_week_card.dart';

/// Tes tata letak kartu runtutan **mingguan** (bulatan per-hari).
///
/// Kartu ini memuat tujuh kolom berdampingan, jadi ia yang paling berisiko
/// meluber di layar HP sempit — terutama karena di lingkungan tes setiap huruf
/// dihitung selebar penuh. Kalau ada yang tidak muat, Flutter melempar
/// RenderFlex overflow saat `pumpWidget` dan tesnya langsung gagal.
void main() {
  // Senin–Minggu (2026-09-28 adalah hari Senin).
  const Set<String> tuntasPenuh = <String>{
    '2026-09-28',
    '2026-09-29',
    '2026-09-30',
  };

  Future<void> render(
    WidgetTester tester, {
    required double lebar,
    required bool terang,
    Set<String> tuntas = tuntasPenuh,
    Set<String>? sebagian,
    bool tuntasHariIni = true,
    int runtutan = 0,
  }) async {
    tester.view.physicalSize = Size(lebar, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: StreakWeekCard(
              judul: 'Runtutan Baca Al-Qur\'an',
              ikon: Icons.menu_book_rounded,
              runtutan: runtutan,
              tanggalTuntas: tuntas,
              tanggalSebagian: sebagian,
              tuntasHariIni: tuntasHariIni,
              keteranganHariIni: 'Progres hari ini: 4/10 ayat',
              terang: terang,
              // Dipatok supaya hasilnya sama di mesin mana pun.
              sekarang: DateTime(2026, 10, 1, 9, 30),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tidak meluber di palet terang (halaman Quran)', (tester) async {
    for (final double lebar in <double>[360, 500, 900]) {
      await render(tester, lebar: lebar, terang: true);
    }
  });

  testWidgets('tidak meluber di palet tema (halaman Dzikir)', (tester) async {
    for (final double lebar in <double>[360, 500, 900]) {
      await render(tester, lebar: lebar, terang: false);
    }
  });

  testWidgets('tidak meluber dengan runtutan panjang & belum ada yang tuntas', (
    tester,
  ) async {
    for (final double lebar in <double>[360, 500]) {
      await render(
        tester,
        lebar: lebar,
        terang: true,
        tuntas: const <String>{},
        tuntasHariIni: false,
        runtutan: 1234,
      );
    }
  });

  testWidgets('tidak meluber saat ada hari yang cuma selesai sebagian', (
    tester,
  ) async {
    // Hari sebagian digambar pakai CustomPaint, jadi dipastikan juga tidak
    // merusak tata letaknya.
    for (final double lebar in <double>[360, 500, 900]) {
      await render(
        tester,
        lebar: lebar,
        terang: false,
        sebagian: const <String>{'2026-09-28', '2026-09-30'},
      );
    }
  });

  testWidgets('menampilkan tujuh hari dan centang hanya pada yang tuntas', (
    tester,
  ) async {
    await render(tester, lebar: 400, terang: true);

    for (final String label in <String>[
      'Sen',
      'Sel',
      'Rab',
      'Kam',
      'Jum',
      'Sab',
      'Min',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    // Tiga hari tuntas → tiga centang.
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
    expect(find.text('0 hari'), findsOneWidget);
  });

  testWidgets('hari sebagian tidak dapat centang, tapi tetap dihitung', (
    tester,
  ) async {
    await render(
      tester,
      lebar: 400,
      terang: true,
      tuntas: const <String>{'2026-09-28', '2026-09-29'},
      sebagian: const <String>{'2026-09-29'},
    );

    // Senin penuh (1 centang), Selasa sebagian (tanpa centang).
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(1));
  });

  testWidgets('menampilkan jumlah runtutan dan keterangan hari ini', (
    tester,
  ) async {
    await render(
      tester,
      lebar: 400,
      terang: false,
      runtutan: 12,
      tuntas: const <String>{},
      tuntasHariIni: false,
    );

    expect(find.text('12 hari'), findsOneWidget);
    expect(find.text('Runtutan Baca Al-Qur\'an'), findsOneWidget);
    expect(find.text('Progres hari ini: 4/10 ayat'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });
}
