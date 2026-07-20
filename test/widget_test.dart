import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:insyira_muslim_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Bangun aplikasi kita
    await tester.pumpWidget(const InsyiraApp());

    // Memastikan aplikasi berhasil berjalan dan memuat teks 'Insyira'
    expect(find.text('Insyira'), findsWidgets);
  });
}
