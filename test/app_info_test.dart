import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:insyira_muslim_app/app_info.dart';

/// Tes penjaga supaya versi aplikasi tidak pernah berbeda antara yang
/// ditampilkan di halaman Tentang dan yang benar-benar dirilis.
///
/// Halaman Tentang, kartu "Tentang" di Pengaturan, dan sidebar semuanya
/// membaca `AppInfo.versi` / `AppInfo.nomorBuild` — sedangkan Google Play
/// membaca `version:` di `pubspec.yaml`. Kalau salah satunya dinaikkan tanpa
/// yang lain, tes ini akan gagal dan menunjuk apa yang harus disamakan.
void main() {
  test('AppInfo.versi & nomorBuild sama dengan version: di pubspec.yaml', () {
    final File berkas = File('pubspec.yaml');
    expect(
      berkas.existsSync(),
      isTrue,
      reason: 'pubspec.yaml tidak ditemukan — jalankan tes dari akar proyek.',
    );

    final RegExpMatch? cocok = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(berkas.readAsStringSync());

    expect(
      cocok,
      isNotNull,
      reason: 'Baris "version:" tidak ditemukan di pubspec.yaml.',
    );

    final String nilaiPubspec = cocok!.group(1)!;
    final String nilaiAppInfo = '${AppInfo.versi}+${AppInfo.nomorBuild}';

    expect(
      nilaiAppInfo,
      nilaiPubspec,
      reason:
          'pubspec.yaml berisi "$nilaiPubspec" tetapi AppInfo berisi '
          '"$nilaiAppInfo". Samakan keduanya di lib/app_info.dart.',
    );
  });

  test('versiLengkap dirangkai dari versi + nomorBuild', () {
    expect(
      AppInfo.versiLengkap,
      '${AppInfo.versi} (build ${AppInfo.nomorBuild})',
    );
  });
}
