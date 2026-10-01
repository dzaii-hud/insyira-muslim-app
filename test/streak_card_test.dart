import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insyira_muslim_app/services/streak_service.dart';
import 'package:insyira_muslim_app/widgets/streak_card.dart';

/// Tes tata letak kartu "Runtutan Harian".
///
/// Kartu ini berisi dua kolom berdampingan di dalam layar HP yang sempit, dan
/// angkanya bisa jadi panjang (runtutan ratusan hari). Yang dicari tes ini
/// adalah **RenderFlex overflow** — kalau ada isi yang tidak muat, Flutter
/// melempar error saat `pumpWidget` dan tesnya langsung gagal.
void main() {
  Future<void> render(
    WidgetTester tester, {
    required double lebar,
    required RingkasanStreak ringkasan,
  }) async {
    // Ukuran HP terkecil yang realistis (360 dp) sampai tablet.
    tester.view.physicalSize = Size(lebar, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: StreakCard(ringkasan: ringkasan),
          ),
        ),
      ),
    );
  }

  RingkasanStreak ringkasan({
    int dzikir = 0,
    int quran = 0,
    bool pagi = false,
    bool sore = false,
    int ayat = 0,
    int halaman = 0,
  }) => RingkasanStreak(
    dzikir: dzikir,
    quran: quran,
    pagiTuntas: pagi,
    soreTuntas: sore,
    dzikirHariIniTuntas: pagi && sore,
    progresQuran: ProgresQuran(ayat: ayat, halaman: halaman),
  );

  testWidgets('tidak meluber saat belum ada runtutan', (tester) async {
    for (final double lebar in <double>[360, 500, 900]) {
      await render(tester, lebar: lebar, ringkasan: ringkasan());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('tidak meluber dengan runtutan panjang & progres sebagian', (
    tester,
  ) async {
    for (final double lebar in <double>[360, 500, 900]) {
      await render(
        tester,
        lebar: lebar,
        ringkasan: ringkasan(
          dzikir: 1234,
          quran: 987,
          pagi: true,
          sore: false,
          ayat: 9,
        ),
      );
      await tester.pumpAndSettle();
    }
  });

  testWidgets('tidak meluber saat keduanya sudah tuntas', (tester) async {
    for (final double lebar in <double>[360, 500, 900]) {
      await render(
        tester,
        lebar: lebar,
        ringkasan: ringkasan(
          dzikir: 30,
          quran: 12,
          pagi: true,
          sore: true,
          ayat: 10,
        ),
      );
      await tester.pumpAndSettle();
    }
  });

  testWidgets('menampilkan angka runtutan dan status hari ini', (tester) async {
    await render(
      tester,
      lebar: 400,
      ringkasan: ringkasan(dzikir: 7, quran: 3, pagi: true, ayat: 4),
    );
    await tester.pumpAndSettle();

    expect(find.text('Runtutan Harian'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    // Dzikir pagi sudah, sore belum → harinya TETAP dihitung runtutan, jadi
    // keterangannya menyebut bahwa baru satu yang selesai (bukan "belum").
    expect(find.text('baru 1 dari 2 dzikir'), findsOneWidget);
    expect(find.text('4/10 ayat'), findsOneWidget);
  });

  testWidgets('menyebut keduanya belum kalau tidak ada dzikir yang selesai', (
    tester,
  ) async {
    await render(tester, lebar: 400, ringkasan: ringkasan(dzikir: 0, quran: 0));
    await tester.pumpAndSettle();

    expect(find.text('belum: pagi & sore'), findsOneWidget);
  });

  testWidgets('menandai centang kalau suatu runtutan sudah tuntas hari ini', (
    tester,
  ) async {
    await render(
      tester,
      lebar: 400,
      ringkasan: ringkasan(
        dzikir: 2,
        quran: 2,
        pagi: true,
        sore: true,
        ayat: 10,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('pagi & sore selesai'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
  });
}
