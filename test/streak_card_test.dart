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
  /// Pukul 08:00 — dzikir pagi DAN petang dua-duanya masih terbuka.
  ///
  /// ⚠️ Waktu ini WAJIB dipasok ke kartu. Tanpa itu, keterangan dzikir
  /// berubah sendiri menurut jam berapa tesnya dijalankan (setelah 11:00
  /// dzikir pagi tutup, setelah 18:00 tutup keduanya) dan tesnya gagal
  /// secara acak. Itu bukan teori: kartu ini sempat menulis "selesaikan
  /// dzikir pagi & sore" pada pukul 20:28.
  final DateTime pagiHari = DateTime(2026, 10, 5, 8);

  Future<void> render(
    WidgetTester tester, {
    required double lebar,
    required RingkasanStreak ringkasan,
    DateTime? sekarang,
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
            child: StreakCard(
              ringkasan: ringkasan,
              sekarang: sekarang ?? pagiHari,
            ),
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

  // --- Kartu wajib sadar jam: jangan menyuruh yang mustahil ---

  testWidgets('sebut dzikir pagi TERLEWAT kalau batas 11:00 sudah lewat', (
    tester,
  ) async {
    await render(
      tester,
      lebar: 400,
      // 13:00 — dzikir pagi sudah tutup, petang masih terbuka.
      sekarang: DateTime(2026, 10, 5, 13),
      ringkasan: ringkasan(),
    );
    await tester.pumpAndSettle();

    expect(find.text('pagi terlewat · sore belum'), findsOneWidget);
    expect(
      find.textContaining('Waktu dzikir pagi sudah lewat'),
      findsOneWidget,
    );
    expect(find.textContaining('dzikir petang'), findsOneWidget);
    // Bunyi lama menyuruh "Selesaikan dzikir pagi & sore" — itu mustahil.
    expect(find.textContaining('Selesaikan dzikir pagi & sore'), findsNothing);
  });

  testWidgets('pukul 20:28 tidak lagi menyuruh dzikir pagi & sore', (
    tester,
  ) async {
    // Jam persis dari tangkapan layar tester 5 Okt 2026.
    await render(
      tester,
      lebar: 400,
      sekarang: DateTime(2026, 10, 5, 20, 28),
      ringkasan: ringkasan(),
    );
    await tester.pumpAndSettle();

    expect(find.text('terlewat: pagi & sore'), findsOneWidget);
    expect(
      find.textContaining('sudah lewat (pagi 11:00, petang 18:00)'),
      findsOneWidget,
    );
    expect(find.textContaining('dzikir dilanjut besok'), findsOneWidget);
    // Tidak boleh menyuruh mengejar dzikir yang sudah tutup.
    expect(find.textContaining('Selesaikan dzikir pagi'), findsNothing);
    expect(find.textContaining('Selesaikan dzikir petang'), findsNothing);
  });

  testWidgets('tidak meluber di semua keadaan waktu', (tester) async {
    for (final DateTime saat in <DateTime>[
      DateTime(2026, 10, 5, 8),
      DateTime(2026, 10, 5, 13),
      DateTime(2026, 10, 5, 20, 28),
    ]) {
      for (final double lebar in <double>[360, 400, 900]) {
        await render(
          tester,
          lebar: lebar,
          sekarang: saat,
          ringkasan: ringkasan(),
        );
        await tester.pumpAndSettle();
      }
    }
  });
}
