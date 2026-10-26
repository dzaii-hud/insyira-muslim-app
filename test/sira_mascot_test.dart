import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insyira_muslim_app/services/tips_sira.dart';
import 'package:insyira_muslim_app/widgets/sira_mascot.dart';
import 'package:insyira_muslim_app/widgets/sira_tips_sheet.dart';

/// Menguji Sira sebagai gambar & lembar tipsnya.
///
/// Maskot ini digambar dengan `CustomPainter`, jadi kesalahan yang paling
/// mungkin terjadi bukan "terlihat jelek" melainkan **crash atau meluber** di
/// ukuran tertentu — mis. 26 px di Pengaturan dan 64 px di lembar tips. Karena
/// itu tes ini memompa beberapa ukuran sekaligus memeriksa
/// `tester.takeException()`.
void main() {
  group('gambar Sira', () {
    for (final double ukuran in <double>[18, 26, 40, 56, 64, 96, 140]) {
      testWidgets('tidak bermasalah di ukuran $ukuran px', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(child: SiraMascot(ukuran: ukuran)),
          ),
        );

        // Biarkan animasi berjalan beberapa bingkai.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 600));

        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(SiraMascot)), Size(ukuran, ukuran));
      });
    }

    for (final SiraEkspresi ekspresi in SiraEkspresi.values) {
      testWidgets('ekspresi ${ekspresi.name} bisa digambar', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Center(child: SiraMascot(ekspresi: ekspresi)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('animasi bisa dimatikan tanpa error', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(child: SiraMascot(ukuran: 26, animasi: false)),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
    });
  });

  group('lembar tips', () {
    const TipsSira tips = TipsSira(
      judul: 'Jadwal Kajian',
      poin: <String>[
        'Kajian hari ini ditandai.',
        'Ketuk untuk melihat rincian.',
      ],
    );

    testWidgets('menampilkan judul & semua poin', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SiraTipsSheet(tips: tips)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Jadwal Kajian'), findsOneWidget);
      expect(find.text('Sira'), findsOneWidget);

      for (final String poin in tips.poin) {
        expect(find.text(poin), findsOneWidget);
      }
    });

    testWidgets('tidak meluber di layar sempit dengan huruf besar', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: const Scaffold(body: SiraTipsSheet(tips: tips)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });
  });
}
