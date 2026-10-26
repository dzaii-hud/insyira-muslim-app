import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insyira_muslim_app/services/sira_pendamping.dart';
import 'package:insyira_muslim_app/widgets/sira_mascot.dart';
import 'package:insyira_muslim_app/widgets/sira_pengenalan.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Menguji halaman perkenalan Sira.
///
/// Ini satu-satunya layar yang dilihat SEMUA pengguna baru, jadi dua hal yang
/// dijaga: isinya benar-benar bisa dijalani sampai selesai, dan setelah selesai
/// ia tidak muncul lagi (kalau gagal, pengguna lama akan ditawari perkenalan
/// setiap kali membuka aplikasi).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SiraPendamping.instance.pengenalanSelesai.value = false;
    SiraPendamping.instance.aktif.value = true;
  });

  /// Membuka perkenalan dari sebuah tombol, seperti yang dilakukan aplikasi.
  Future<void> buka(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => bukaPengenalanSira(context),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> ketukLanjut(WidgetTester tester) async {
    await tester.tap(find.text('Lanjut'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('halaman pertama memperkenalkan Sira', (
    WidgetTester tester,
  ) async {
    await buka(tester);

    expect(find.text('Kenalan dulu, yuk'), findsOneWidget);
    expect(find.byType(SiraMascot), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bisa dijalani sampai halaman terakhir', (
    WidgetTester tester,
  ) async {
    await buka(tester);

    expect(find.text('Kenalan dulu, yuk'), findsOneWidget);

    await ketukLanjut(tester);
    expect(find.text('Geser aku ke mana saja'), findsOneWidget);

    await ketukLanjut(tester);
    expect(find.text('Ketuk aku kalau bingung'), findsOneWidget);

    await ketukLanjut(tester);
    expect(find.text('Nanti bisa diajak ngobrol'), findsOneWidget);
    expect(find.text('Mulai pakai Insyira'), findsOneWidget);
  });

  testWidgets('selesai menandai perkenalan supaya tidak muncul lagi', (
    WidgetTester tester,
  ) async {
    await buka(tester);

    for (int i = 0; i < 3; i++) {
      await ketukLanjut(tester);
    }

    await tester.tap(find.text('Mulai pakai Insyira'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(SiraPendamping.instance.pengenalanSelesai.value, isTrue);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(SiraPendamping.kunciPengenalanSelesai), isTrue);

    // Lembarnya sudah tertutup.
    expect(find.text('Mulai pakai Insyira'), findsNothing);
  });

  testWidgets('tombol Lewati juga menandai selesai', (
    WidgetTester tester,
  ) async {
    await buka(tester);

    await tester.tap(find.text('Lewati'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(SiraPendamping.instance.pengenalanSelesai.value, isTrue);
    expect(find.text('Kenalan dulu, yuk'), findsNothing);
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
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: const Scaffold(body: SiraPengenalan()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
  });
}
