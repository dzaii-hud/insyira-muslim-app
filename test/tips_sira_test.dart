import 'package:flutter_test/flutter_test.dart';
import 'package:insyira_muslim_app/router/app_router.dart';
import 'package:insyira_muslim_app/services/tips_sira.dart';

/// Menguji pemilihan tips maskot Sira.
///
/// Yang dijaga di sini bukan tampilannya, melainkan **isi dan sasaran** tips:
/// kalau alamat halaman berubah, Sira tidak boleh diam-diam berhenti muncul
/// (atau menampilkan tips halaman yang salah). Keduanya gagal tanpa suara di
/// aplikasi — tidak ada error, hanya tips yang tidak pernah muncul.
void main() {
  group('tips tab Home', () {
    for (int tab = 0; tab < 5; tab++) {
      test('tab $tab punya tips', () {
        final TipsSira? tips = cariTipsSira(rute: AppRoutes.home, tab: tab);

        expect(tips, isNotNull);
        expect(tips!.judul, isNotEmpty);
        expect(tips.poin, isNotEmpty);
      });
    }

    test('nomor tab di luar rentang memakai tips tab pertama', () {
      final TipsSira? tips = cariTipsSira(rute: AppRoutes.home, tab: 99);

      expect(tips?.judul, kTipsSiraHome[0]!.judul);
    });
  });

  group('tips halaman lain', () {
    test('halaman yang diizinkan punya tips', () {
      for (final String rute in <String>[
        AppRoutes.fawaidh,
        AppRoutes.fawaidhSaya,
        AppRoutes.settings,
        AppRoutes.about,
      ]) {
        expect(
          cariTipsSira(rute: rute, tab: 0),
          isNotNull,
          reason: 'Halaman $rute tidak punya tips — Sira tidak akan muncul.',
        );
      }
    });

    test('halaman baca fawaidh (/fawaidh/<id>) punya tips', () {
      expect(cariTipsSira(rute: '/fawaidh/12', tab: 0), isNotNull);
    });

    test('halaman baca Al-Quran & pemutar video tidak punya tips', () {
      // Dua halaman ini sengaja tidak ditemani Sira: pengguna sedang fokus.
      expect(cariTipsSira(rute: '/surah/2', tab: 0), isNull);
      expect(cariTipsSira(rute: '/tonton/abc123', tab: 0), isNull);
    });

    test('splash & login tidak punya tips', () {
      expect(cariTipsSira(rute: AppRoutes.splash, tab: 0), isNull);
      expect(cariTipsSira(rute: AppRoutes.login, tab: 0), isNull);
    });
  });

  test('tiap poin tips cukup pendek untuk dibaca', () {
    final Iterable<TipsSira> semua = <TipsSira>[
      ...kTipsSiraHome.values,
      ...kTipsSiraHalaman.values,
    ];

    for (final TipsSira tips in semua) {
      // Tips yang panjang tidak dibaca sampai habis di lembar bawah.
      expect(tips.poin.length, lessThanOrEqualTo(4), reason: tips.judul);

      for (final String poin in tips.poin) {
        expect(
          poin.length,
          lessThanOrEqualTo(200),
          reason: 'Terlalu panjang: $poin',
        );
      }
    }
  });
}
