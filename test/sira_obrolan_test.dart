import 'package:flutter_test/flutter_test.dart';
import 'package:insyira_muslim_app/services/sira_obrolan.dart';
import 'package:insyira_muslim_app/services/streak_service.dart';
import 'package:insyira_muslim_app/services/tips_sira.dart';

/// Menguji "otak" obrolan Sira.
///
/// Yang dijaga di sini bukan suara Sira, melainkan **ketepatan sasarannya**:
/// pertanyaan tentang adzan tidak boleh dijawab dengan tips kiblat, dan
/// jawaban tentang halaman harus menyebut halaman yang benar-benar dibuka.
/// Kesalahan seperti itu tidak memunculkan error apa pun — hanya jawaban yang
/// terasa ngawur.
void main() {
  final DateTime sekarang = DateTime(2026, 10, 29, 15, 12);

  final Map<String, DateTime> jadwalHariIni = <String, DateTime>{
    'Subuh': DateTime(2026, 10, 29, 4, 45),
    'Dzuhur': DateTime(2026, 10, 29, 11, 58),
    'Ashar': DateTime(2026, 10, 29, 15, 30),
    'Maghrib': DateTime(2026, 10, 29, 18, 4),
    'Isya': DateTime(2026, 10, 29, 19, 15),
  };

  SiraObrolan otak({
    Map<String, DateTime>? jadwal,
    RingkasanStreak? runtutan,
  }) => SiraObrolan(
    jadwalSholat: () async => jadwal ?? <String, DateTime>{},
    runtutan: () async => runtutan,
  );

  KonteksSira di(String halaman, {int tab = 0}) =>
      KonteksSira(halaman: halaman, tabHome: tab, jam: sekarang);

  group('sapaan', () {
    test('menyebut halaman yang sedang dibuka', () async {
      final BalasanSira b = await otak().jawab(
        'halo',
        konteks: di(HalamanSira.pengaturan),
      );

      expect(b.teks, startsWith('Halo'));
      expect(b.teks, contains('Pengaturan'));
      expect(b.saran, isNotEmpty);
    });

    test('menjawab salam dengan salam', () async {
      final BalasanSira b = await otak().jawab(
        'assalamualaikum sira',
        konteks: di(HalamanSira.home),
      );

      expect(b.teks, contains("Wa'alaikumussalam"));
    });
  });

  group('kesadaran halaman', () {
    test('pertanyaan "di sini" dijawab dengan halaman video', () async {
      final BalasanSira b = await otak().jawab(
        'ini halaman apa ya',
        konteks: di(HalamanSira.tonton),
      );

      expect(b.teks, contains('Memutar Video Kajian'));
    });

    test('pertanyaan "halaman ini" dijawab dengan halaman pengaturan', () async {
      final BalasanSira b = await otak().jawab(
        'apa yang bisa aku lakukan di halaman ini',
        konteks: di(HalamanSira.pengaturan),
      );

      expect(b.teks, contains('Pengaturan'));
    });
  });

  group('jadwal sholat', () {
    test('menyebut sholat berikutnya, bukan yang sudah lewat', () async {
      final BalasanSira b = await otak(
        jadwal: jadwalHariIni,
      ).jawab('jadwal sholat hari ini', konteks: di(HalamanSira.home));

      expect(b.teks, contains('ashar'));
      expect(b.teks, contains('15.30'));
      expect(b.teks, contains('18 menit'));
    });

    test('menjawab satu waktu sholat yang ditanyakan', () async {
      final BalasanSira b = await otak(
        jadwal: jadwalHariIni,
      ).jawab('jam berapa maghrib', konteks: di(HalamanSira.home));

      expect(b.teks, contains('Maghrib'));
      expect(b.teks, contains('18.04'));
    });

    test('jujur kalau jadwal belum tersedia', () async {
      final BalasanSira b = await otak().jawab(
        'kapan sholat subuh',
        konteks: di(HalamanSira.home),
      );

      expect(b.teks, contains('belum tersedia'));
    });

    test('jadwal kemarin tidak dipakai untuk hari ini', () async {
      final BalasanSira b = await otak(
        jadwal: <String, DateTime>{
          'Subuh': DateTime(2026, 10, 28, 4, 45),
          'Isya': DateTime(2026, 10, 28, 19, 15),
        },
      ).jawab('jadwal sholat hari ini', konteks: di(HalamanSira.home));

      expect(b.teks, contains('belum tersedia'));
    });
  });

  group('bantuan pemakaian', () {
    test('adzan yang tidak berbunyi dijawab dengan langkah periksa', () async {
      final BalasanSira b = await otak().jawab(
        'kenapa adzan tidak berbunyi',
        konteks: di(HalamanSira.pengaturan),
      );

      expect(b.teks.toLowerCase(), contains('penghemat'));
      expect(b.teks.toLowerCase(), contains('notifikasi'));
    });

    test('runtutan dijawab dengan angka milik pengguna', () async {
      final BalasanSira b = await otak(
        runtutan: const RingkasanStreak(
          dzikir: 3,
          quran: 2,
          pagiTuntas: true,
          soreTuntas: false,
          dzikirHariIniTuntas: false,
          progresQuran: ProgresQuran(ayat: 4, halaman: 0),
        ),
      ).jawab('runtutanku berapa', konteks: di(HalamanSira.home));

      expect(b.teks, contains('dzikir 3 hari'));
      expect(b.teks, contains("Al-Qur'an 2 hari"));
      expect(b.teks, contains('4/10 ayat'));
    });

    test('pertanyaan yang tidak dikenal dijawab jujur', () async {
      final BalasanSira b = await otak().jawab(
        'warna favoritmu apa',
        konteks: di(HalamanSira.home),
      );

      expect(b.teks, contains('belum paham'));
      expect(b.saran, isNotEmpty);
    });
  });

  group('saran pertanyaan', () {
    test('setiap saran benar-benar dijawab, bukan jatuh ke "belum paham"', () async {
      final List<String> halaman = <String>[
        HalamanSira.home,
        HalamanSira.pengaturan,
        HalamanSira.tentang,
        HalamanSira.tonton,
        HalamanSira.fawaidh,
        HalamanSira.fawaidhBaca,
        HalamanSira.fawaidhSaya,
        'surah-detail',
      ];

      for (final String nama in halaman) {
        for (int tab = 0; tab < 5; tab++) {
          final KonteksSira konteks = di(nama, tab: tab);
          final List<String> saran = otak().saranUntuk(konteks);

          expect(saran, isNotEmpty, reason: '$nama tab $tab tidak punya saran');

          for (final String tanya in saran) {
            final BalasanSira b = await otak(
              jadwal: jadwalHariIni,
              runtutan: const RingkasanStreak(
                dzikir: 0,
                quran: 0,
                pagiTuntas: false,
                soreTuntas: false,
                dzikirHariIniTuntas: false,
                progresQuran: ProgresQuran(ayat: 0, halaman: 0),
              ),
            ).jawab(tanya, konteks: konteks);

            expect(
              b.teks,
              isNot(contains('belum paham')),
              reason: 'Saran "$tanya" tidak dikenali oleh Sira',
            );
          }
        }
      }
    });
  });
}
