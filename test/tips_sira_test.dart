import 'package:flutter_test/flutter_test.dart';
import 'package:insyira_muslim_app/services/tips_sira.dart';

/// Menguji pemilihan tips maskot Sira.
///
/// Yang dijaga di sini bukan tampilannya, melainkan **isi dan sasaran** tips:
/// kalau nama route berubah, Sira tidak boleh diam-diam berhenti muncul (atau
/// menampilkan tips halaman yang salah). Keduanya gagal tanpa suara di
/// aplikasi — tidak ada error, hanya tips yang tidak pernah muncul.
void main() {
  group('tips tab Home', () {
    for (int tab = 0; tab < 5; tab++) {
      test('tab $tab punya tips', () {
        final TipsSira? tips = cariTipsSira(
          namaHalaman: HalamanSira.home,
          tab: tab,
        );

        expect(tips, isNotNull);
        expect(tips!.judul, isNotEmpty);
        expect(tips.poin, isNotEmpty);
      });
    }

    test('nomor tab di luar rentang memakai tips tab pertama', () {
      final TipsSira? tips = cariTipsSira(
        namaHalaman: HalamanSira.home,
        tab: 99,
      );

      expect(tips?.judul, kTipsSiraHome[0]!.judul);
    });
  });

  group('tips halaman lain', () {
    test('halaman yang diizinkan punya tips', () {
      for (final String halaman in <String>[
        HalamanSira.fawaidh,
        HalamanSira.fawaidhBaca,
        HalamanSira.fawaidhSaya,
        HalamanSira.pengaturan,
        HalamanSira.tentang,
        HalamanSira.tonton,
      ]) {
        expect(
          cariTipsSira(namaHalaman: halaman, tab: 0),
          isNotNull,
          reason: 'Halaman $halaman tidak punya tips — Sira tidak akan muncul.',
        );
      }
    });

    test('halaman baca Al-Quran tidak punya tips', () {
      // Halaman ini sengaja tidak ditemani Sira: pengguna sedang fokus membaca.
      expect(cariTipsSira(namaHalaman: 'surah-detail', tab: 0), isNull);
    });

    test('halaman yang belum dikenal tidak punya tips', () {
      expect(cariTipsSira(namaHalaman: '', tab: 0), isNull);
      expect(cariTipsSira(namaHalaman: 'splash', tab: 0), isNull);
      expect(cariTipsSira(namaHalaman: 'login', tab: 0), isNull);
    });
  });

  group('nama halaman dari alamat', () {
    test('alamat yang didukung dikenali', () {
      expect(namaHalamanDariJalur('/home'), HalamanSira.home);
      expect(namaHalamanDariJalur('/settings'), HalamanSira.pengaturan);
      expect(namaHalamanDariJalur('/tentang'), HalamanSira.tentang);
      expect(namaHalamanDariJalur('/fawaidh'), HalamanSira.fawaidh);
      expect(namaHalamanDariJalur('/fawaidh/12'), HalamanSira.fawaidhBaca);
      expect(namaHalamanDariJalur('/tonton/abc123'), HalamanSira.tonton);
    });

    test('alamat lainnya menghasilkan kosong', () {
      expect(namaHalamanDariJalur('/surah/2'), '');
    });
  });

  test('tiap poin tips cukup pendek untuk dibaca', () {
    for (final TipsSira tips in <TipsSira>[
      ...kTipsSiraHome.values,
      ...kTipsSiraHalaman.values,
    ]) {
      // Tips yang panjang tidak dibaca sampai habis di gulungan.
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
