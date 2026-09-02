import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:insyira_muslim_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Bangun aplikasi kita dengan dark mode default
    await tester.pumpWidget(const InsyiraApp(isDarkMode: true));

    // Tunggu splash screen selesai (3 detik)
    await tester.pump(const Duration(seconds: 4));

    // Memastikan aplikasi berhasil berjalan
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
