import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:insyira_muslim_app/services/sira_observer.dart';
import 'package:insyira_muslim_app/services/sira_pendamping.dart';

void main() {
  late GoRouter router;

  setUp(() {
    SiraPendamping.instance.laporkanHalaman('');
    router = GoRouter(
      initialLocation: '/home',
      observers: <NavigatorObserver>[SiraObserver()],
      routes: <RouteBase>[
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('settings')),
        ),
      ],
    );
  });

  testWidgets('push melaporkan halaman baru', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(SiraPendamping.instance.namaHalaman.value, 'home');

    router.push('/settings');
    await tester.pumpAndSettle();

    expect(SiraPendamping.instance.namaHalaman.value, 'settings');
  });
}
