import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insyira_muslim_app/services/sira_pendamping.dart';
import 'package:insyira_muslim_app/services/tips_sira.dart';
import 'package:insyira_muslim_app/theme/app_theme.dart';
import 'package:insyira_muslim_app/widgets/sira_obrolan_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Menguji lembar obrolan Sira sebagai antarmuka.
///
/// Yang paling mudah rusak tanpa terlihat: pesan baru tidak ikut tergulir,
/// tombol kirim tetap aktif saat Sira masih menjawab (sehingga pertanyaan
/// ganda menumpuk), dan lembar gagal dibuka karena masalah konteks navigator.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SiraPendamping.instance.laporkanHalaman(HalamanSira.pengaturan);
    SiraPendamping.instance.laporkanTabHome(0);
  });

  Future<void> buka(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => bukaObrolanSira(context),
                child: const Text('Buka obrolan'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka obrolan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('langsung menyapa dan menyebut halaman yang dibuka', (
    WidgetTester tester,
  ) async {
    await buka(tester);

    expect(find.text('Obrolan dengan Sira'), findsOneWidget);
    expect(find.text('Tahu kamu di halaman Pengaturan'), findsOneWidget);
    expect(
      find.textContaining('Sekarang kamu di halaman Pengaturan'),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('menjawab pertanyaan yang diketik', (WidgetTester tester) async {
    await buka(tester);

    await tester.enterText(
      find.byType(TextField),
      'kenapa adzan tidak berbunyi',
    );
    await tester.tap(find.byTooltip('Kirim'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('kenapa adzan tidak berbunyi'), findsOneWidget);
    expect(find.textContaining('Penghemat baterai'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saran pertanyaan bisa diketuk', (WidgetTester tester) async {
    await buka(tester);

    await tester.tap(find.text('Kenapa adzan tidak berbunyi?').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.textContaining('Status Notifikasi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tidak meluber di layar sempit dengan huruf besar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await buka(tester);

    expect(find.text('Obrolan dengan Sira'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
