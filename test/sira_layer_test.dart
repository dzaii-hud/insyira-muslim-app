import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insyira_muslim_app/services/sira_pendamping.dart';
import 'package:insyira_muslim_app/services/tips_sira.dart';
import 'package:insyira_muslim_app/widgets/sira_layer.dart';
import 'package:insyira_muslim_app/widgets/sira_mascot.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Menguji aturan "kapan Sira muncul".
///
/// Aturan ini yang menentukan maskot terasa menemani atau mengganggu, dan
/// salah satunya tidak terlihat di layar: Sira harus benar-benar **keluar dari
/// pohon widget** saat disembunyikan, bukan hanya transparan — kalau tidak,
/// pembaca layar masih bisa memfokuskan tombol yang tidak kelihatan.
void main() {
  setUp(() {
    // Penghitung "sudah dimatikan pengguna" disimpan di SharedPreferences.
    // Tanpa tiruan ini, `setAktif` menunggu saluran platform yang tidak ada di
    // lingkungan tes — dan tesnya menggantung, bukan gagal.
    SharedPreferences.setMockInitialValues(<String, Object>{});

    SiraPendamping.instance.aktif.value = true;
    SiraPendamping.instance.adaLapisanDiAtas.value = false;
    SiraPendamping.instance.rute.value = '';
    SiraPendamping.instance.laporkanTabHome(0);
    SiraPendamping.instance.posisi.value = null;

    // Perkenalan diuji terpisah; di sini dianggap sudah pernah dilihat supaya
    // tidak menutupi halaman saat tes lain berjalan.
    SiraPendamping.instance.pengenalanSelesai.value = true;
  });

  /// Memompa lapisan Sira lalu memindahkannya ke halaman [rute].
  ///
  /// Rute diset SETELAH pump pertama: `SiraLayer` membaca alamat router saat
  /// dibuat, dan di tes ini routernya belum pernah berpindah halaman.
  Future<void> pumpDiRute(
    WidgetTester tester,
    String rute, {
    int tab = 0,
    Widget? mediaQuery,
  }) async {
    Widget lapisan = SiraLayer(child: const Scaffold(body: SizedBox.expand()));
    if (mediaQuery != null) lapisan = mediaQuery;

    await tester.pumpWidget(MaterialApp(home: lapisan));
    await tester.pump(const Duration(milliseconds: 300));

    SiraPendamping.instance.rute.value = rute;
    SiraPendamping.instance.laporkanTabHome(tab);
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('muncul di halaman Home', (WidgetTester tester) async {
    await pumpDiRute(tester, '/home');

    expect(find.byType(SiraMascot), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muncul dengan label tips tab yang sedang dibuka', (
    WidgetTester tester,
  ) async {
    await pumpDiRute(tester, '/home', tab: 3);

    expect(find.byType(SiraMascot), findsOneWidget);
    expect(
      find.bySemanticsLabel('Sira: ${kTipsSiraHome[3]!.judul}'),
      findsOneWidget,
    );
  });

  testWidgets('tidak muncul di halaman baca Al-Quran', (
    WidgetTester tester,
  ) async {
    await pumpDiRute(tester, '/surah/2');

    expect(find.byType(SiraMascot), findsNothing);
  });

  testWidgets('tidak muncul saat dimatikan dari Pengaturan', (
    WidgetTester tester,
  ) async {
    await pumpDiRute(tester, '/home');
    expect(find.byType(SiraMascot), findsOneWidget);

    await SiraPendamping.instance.setAktif(false);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SiraMascot), findsNothing);
  });

  testWidgets('menghilang saat ada lembar bawah di atas halaman', (
    WidgetTester tester,
  ) async {
    await pumpDiRute(tester, '/settings');
    expect(find.byType(SiraMascot), findsOneWidget);

    SiraPendamping.instance.adaLapisanDiAtas.value = true;
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SiraMascot), findsNothing);
  });

  testWidgets('menghilang saat papan tombol terbuka', (
    WidgetTester tester,
  ) async {
    await pumpDiRute(
      tester,
      '/home',
      mediaQuery: const MediaQuery(
        data: MediaQueryData(
          viewInsets: EdgeInsets.only(bottom: 320),
          size: Size(400, 800),
        ),
        child: SiraLayer(child: Scaffold(body: SizedBox.expand())),
      ),
    );

    expect(find.byType(SiraMascot), findsNothing);
  });

  testWidgets('ketukan tidak membuat aplikasi error ', (
    WidgetTester tester,
  ) async {
    await pumpDiRute(tester, '/home');

    await tester.tap(find.byType(SiraMascot));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });

  /// Gelembung Sira (bukan gambar lenteranya) — bagian yang posisinya diatur
  /// oleh lapisan ini.
  Finder gelembungSira() => find
      .ancestor(
        of: find.byType(SiraMascot),
        matching: find.byType(GestureDetector),
      )
      .first;

  testWidgets('bisa digeser, dan posisi barunya diingat', (
    WidgetTester tester,
  ) async {
    await pumpDiRute(tester, '/home');

    final Offset awal = tester.getTopLeft(gelembungSira());

    await tester.drag(gelembungSira(), const Offset(-150, -300));
    await tester.pump(const Duration(milliseconds: 400));

    final Offset akhir = tester.getTopLeft(gelembungSira());
    expect(akhir.dx, lessThan(awal.dx));
    expect(akhir.dy, lessThan(awal.dy));

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble(SiraPendamping.kunciPosisiX), isNotNull);
    expect(prefs.getDouble(SiraPendamping.kunciPosisiY), isNotNull);
    expect(SiraPendamping.instance.posisi.value, isNotNull);
  });

  testWidgets('posisi tersimpan dipakai lagi saat halaman dibuka', (
    WidgetTester tester,
  ) async {
    // Posisi di tengah layar, disimpan sebagai pecahan.
    SiraPendamping.instance.posisi.value = const Offset(0.3, 0.4);

    await pumpDiRute(tester, '/home');

    final Rect kotak = tester.getRect(gelembungSira());
    final Size layar = tester.view.physicalSize / tester.view.devicePixelRatio;

    expect(kotak.left / layar.width, closeTo(0.3, 0.01));
    expect(kotak.top / layar.height, closeTo(0.4, 0.01));
  });

  testWidgets('tidak bisa digeser keluar layar', (WidgetTester tester) async {
    await pumpDiRute(tester, '/home');

    // Digeser jauh melewati tepi kanan & atas.
    await tester.drag(gelembungSira(), const Offset(2000, -2000));
    await tester.pump(const Duration(milliseconds: 400));

    final Rect kotak = tester.getRect(gelembungSira());
    expect(kotak.left, greaterThanOrEqualTo(0));
    expect(kotak.top, greaterThanOrEqualTo(0));
  });

  testWidgets('tekan lama tidak membuat aplikasi error', (
    WidgetTester tester,
  ) async {
    await pumpDiRute(tester, '/home');

    await tester.longPress(find.byType(SiraMascot));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
  });
}
