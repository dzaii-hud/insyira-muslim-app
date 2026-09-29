import 'package:flutter_test/flutter_test.dart';
import 'package:insyira_muslim_app/services/notification_service.dart';
import 'package:insyira_muslim_app/services/streak_service.dart';

/// Tes penjaga untuk **runtutan harian** (dzikir 🔥 dan baca Al-Qur'an 📖).
///
/// Aturan yang dijaga di sini — hasil keputusan user 29 Sep 2026:
/// * Dua runtutan dihitung TERPISAH.
/// * Dzikir sehari tuntas kalau **pagi DAN sore** sama-sama selesai.
/// * Quran sehari tuntas kalau **10 ayat** (mode terjemahan) atau
///   **1 halaman** (mode mushaf).
/// * Runtutan **tidak putus** kalau cuma bolong 1–3 hari. Bolong sampai
///   hari ke-4 baru dihitung putus.
void main() {
  /// Senin, 5 Okt 2026 — dipakai sebagai "hari terakhir tuntas" di banyak tes.
  final senin = DateTime(2026, 10, 5);

  group('hitungRuntutanBaru', () {
    test('mulai dari 1 kalau belum pernah tuntas', () {
      expect(
        StreakService.hitungRuntutanBaru(
          runtutanSekarang: 0,
          terakhirSelesai: null,
          hariIni: senin,
        ),
        1,
      );
    });

    test('bertambah 1 pada hari berikutnya', () {
      expect(
        StreakService.hitungRuntutanBaru(
          runtutanSekarang: 4,
          terakhirSelesai: senin,
          hariIni: senin.add(const Duration(days: 1)),
        ),
        5,
      );
    });

    test('tidak bertambah kalau dipanggil dua kali di hari yang sama', () {
      expect(
        StreakService.hitungRuntutanBaru(
          runtutanSekarang: 4,
          terakhirSelesai: senin,
          hariIni: senin.add(const Duration(hours: 20)),
        ),
        4,
      );
    });

    test('bolong 1–3 hari masih menyambung (tetap bertambah 1)', () {
      // 1 hari bolong
      expect(
        StreakService.hitungRuntutanBaru(
          runtutanSekarang: 4,
          terakhirSelesai: senin,
          hariIni: senin.add(const Duration(days: 2)),
        ),
        5,
      );

      // 2 hari bolong
      expect(
        StreakService.hitungRuntutanBaru(
          runtutanSekarang: 4,
          terakhirSelesai: senin,
          hariIni: senin.add(const Duration(days: 3)),
        ),
        5,
      );

      // 3 hari bolong — ini contoh yang ditegaskan user: aktif Senin, lalu
      // tidak sama sekali Selasa–Kamis, aktif lagi Jumat → MASIH lanjut.
      expect(
        StreakService.hitungRuntutanBaru(
          runtutanSekarang: 4,
          terakhirSelesai: senin,
          hariIni: senin.add(const Duration(days: 4)),
        ),
        5,
      );
    });

    test('bolong sampai hari ke-4 → runtutan mulai lagi dari 1', () {
      expect(
        StreakService.hitungRuntutanBaru(
          runtutanSekarang: 12,
          terakhirSelesai: senin,
          hariIni: senin.add(const Duration(days: 5)),
        ),
        1,
      );
    });
  });

  group('runtutanBerlaku', () {
    test('tidak putus selama bolongnya masih 3 hari', () {
      expect(
        StreakService.runtutanBerlaku(
          runtutanTersimpan: 9,
          terakhirSelesai: senin,
          hariIni: senin.add(const Duration(days: 3)),
        ),
        9,
      );

      // Hari ke-4 (Selasa–Kamis bolong, sekarang Jumat) — masih aman.
      expect(
        StreakService.runtutanBerlaku(
          runtutanTersimpan: 9,
          terakhirSelesai: senin,
          hariIni: senin.add(const Duration(days: 4)),
        ),
        9,
      );
    });

    test('jadi 0 setelah ditinggal lebih dari 3 hari', () {
      expect(
        StreakService.runtutanBerlaku(
          runtutanTersimpan: 9,
          terakhirSelesai: senin,
          hariIni: senin.add(const Duration(days: 5)),
        ),
        0,
        reason:
            'runtutan harus terlihat putus tanpa perlu menulis apa pun — '
            'cukup dari jarak tanggalnya',
      );
    });

    test('tetap 0 kalau memang belum pernah ada runtutan', () {
      expect(
        StreakService.runtutanBerlaku(
          runtutanTersimpan: 0,
          terakhirSelesai: null,
          hariIni: senin,
        ),
        0,
      );
    });

    test('menghitung dan menampilkan memakai batas yang SAMA', () {
      // Kalau dua fungsi ini berbeda pendapat, tampilan bisa bilang "putus"
      // padahal pencatatannya masih menyambung (atau sebaliknya).
      //
      // Yang dibandingkan: apakah runtutan masih dianggap HIDUP oleh
      // runtutanBerlaku, dengan apakah pencatatannya TIDAK di-reset (hasilnya
      // lebih dari 1) oleh hitungRuntutanBaru.
      for (int selisih = 0; selisih <= 7; selisih++) {
        final DateTime hariIni = senin.add(Duration(days: selisih));
        final bool masihHidup =
            StreakService.runtutanBerlaku(
              runtutanTersimpan: 5,
              terakhirSelesai: senin,
              hariIni: hariIni,
            ) >
            0;
        final bool tidakDiReset =
            StreakService.hitungRuntutanBaru(
              runtutanSekarang: 5,
              terakhirSelesai: senin,
              hariIni: hariIni,
            ) >
            1;

        expect(
          masihHidup,
          tidakDiReset,
          reason: 'beda pendapat pada selisih $selisih hari',
        );
      }
    });
  });

  group('mingguIni (kartu bulatan per-hari)', () {
    // 2026-09-28 adalah hari SENIN, jadi 2026-10-01 = Kamis.
    final kamis = DateTime(2026, 10, 1, 9, 30);

    test('menyusun Senin sampai Minggu, bukan 7 hari ke belakang', () {
      final hasil = StreakService.mingguIni(
        sekarang: kamis,
        tanggalTuntas: const <String>{},
      );

      expect(hasil, hasLength(7));
      expect(
        hasil.map((HariStreak h) => h.label).toList(),
        StreakService.labelHari,
      );
      expect(hasil.first.tanggal, DateTime(2026, 9, 28));
      expect(hasil.last.tanggal, DateTime(2026, 10, 4));
    });

    test('menandai tepat SATU hari sebagai hari ini', () {
      final hasil = StreakService.mingguIni(
        sekarang: kamis,
        tanggalTuntas: const <String>{},
      );

      expect(hasil.where((HariStreak h) => h.hariIni).length, 1);
      // Kamis = kolom ke-4.
      expect(hasil[3].label, 'Kam');
      expect(hasil[3].hariIni, isTrue);
    });

    test('menandai hari yang tuntas dari daftar tanggal', () {
      final hasil = StreakService.mingguIni(
        sekarang: kamis,
        // Selasa tuntas, Rabu bolong, Kamis belum.
        tanggalTuntas: const <String>{'2026-09-29'},
      );

      expect(hasil[1].label, 'Sel');
      expect(hasil[1].tuntas, isTrue);
      expect(hasil[2].tuntas, isFalse);
      expect(hasil[3].tuntas, isFalse);
    });

    test('hari setelah hari ini ditandai belum terjadi', () {
      final hasil = StreakService.mingguIni(
        sekarang: kamis,
        tanggalTuntas: const <String>{},
      );

      expect(hasil[3].masaDepan, isFalse, reason: 'hari ini bukan masa depan');
      expect(hasil[2].masaDepan, isFalse, reason: 'Rabu sudah lewat');
      expect(hasil[4].masaDepan, isTrue);
      expect(hasil[6].masaDepan, isTrue);
    });

    test('tetap benar kalau hari ini Minggu (kolom terakhir)', () {
      final hasil = StreakService.mingguIni(
        sekarang: DateTime(2026, 10, 4, 22, 0),
        tanggalTuntas: const <String>{},
      );

      expect(hasil.first.tanggal, DateTime(2026, 9, 28));
      expect(hasil.last.label, 'Min');
      expect(hasil.last.hariIni, isTrue);
      expect(hasil.any((HariStreak h) => h.masaDepan), isFalse);
    });
  });

  group('target harian', () {
    test('Quran cukup dengan 10 ayat ATAU 1 halaman', () {
      expect(
        StreakService.quranSudahCukup(ayatHariIni: 9, halamanHariIni: 0),
        isFalse,
      );
      expect(
        StreakService.quranSudahCukup(ayatHariIni: 10, halamanHariIni: 0),
        isTrue,
      );
      expect(
        StreakService.quranSudahCukup(ayatHariIni: 0, halamanHariIni: 1),
        isTrue,
      );
    });

    test('ProgresQuran.teks memilih mode yang paling relevan', () {
      expect(const ProgresQuran(ayat: 7, halaman: 0).teks, '7/10 ayat');
      expect(const ProgresQuran(ayat: 0, halaman: 0).teks, 'belum dibaca');
      expect(const ProgresQuran(ayat: 10, halaman: 0).teks, '10/10 ayat');
      expect(const ProgresQuran(ayat: 0, halaman: 2).teks, '2/1 halaman');
    });
  });

  group('rencanaPengingatStreak', () {
    final sekarang = DateTime(2026, 9, 29, 12, 0);

    List<PengingatStreak> rencana({
      bool hariIniTuntas = false,
      bool dzikirTuntas = false,
      bool quranTuntas = false,
      int runtutanTertinggi = 0,
    }) => StreakService.rencanaPengingatStreak(
      hariIniTuntas: hariIniTuntas,
      dzikirTuntas: dzikirTuntas,
      quranTuntas: quranTuntas,
      runtutanTertinggi: runtutanTertinggi,
      sekarang: sekarang,
    );

    test('dipasang untuk 7 hari, satu per hari pada pukul 20:00', () {
      final hasil = rencana();

      expect(hasil, hasLength(NotificationService.hariPengingatStreakKeDepan));

      for (int h = 0; h < hasil.length; h++) {
        final DateTime tanggal = DateTime(2026, 9, 29 + h);
        expect(
          hasil[h].waktu,
          DateTime(tanggal.year, tanggal.month, tanggal.day, 20),
        );
      }
    });

    test('hari ini DILEWATI kalau semuanya sudah tuntas', () {
      final hasil = rencana(
        hariIniTuntas: true,
        dzikirTuntas: true,
        quranTuntas: true,
      );

      expect(
        hasil,
        hasLength(NotificationService.hariPengingatStreakKeDepan - 1),
      );
      expect(
        hasil.any((PengingatStreak p) => p.waktu.day == 29),
        isFalse,
        reason: 'tidak boleh ada pengingat untuk pekerjaan yang sudah selesai',
      );
    });

    test('menyebut apa yang masih kurang', () {
      final hanyaDzikir = rencana(dzikirTuntas: true);
      expect(hanyaDzikir.first.isi, contains('ayat'));

      final hanyaQuran = rencana(quranTuntas: true);
      expect(hanyaQuran.first.isi, contains('dzikir'));
    });

    test('menyebut runtutan yang bisa putus kalau memang sedang berjalan', () {
      final hasil = rencana(runtutanTertinggi: 12);
      expect(hasil.first.isi, contains('12 hari'));
    });

    test('ID unik, berurutan, dan tidak menabrak notifikasi lain', () {
      final hasil = rencana();
      final id = hasil.map((PengingatStreak p) => p.id).toList();

      expect(id.toSet().length, id.length, reason: 'ada ID pengingat kembar');
      expect(id.first, 2900);
      expect(id.last, 2906);

      // Seluruh ID notifikasi yang dipakai aplikasi ini. Kalau ada fitur baru,
      // tambahkan di sini — tes inilah yang menangkap tabrakan ID.
      const Map<String, List<int>> dipakaiLain = <String, List<int>>{
        'adzan terjadwal': <int>[1100, 1129, 1599],
        'adzan langsung': <int>[1600, 1604],
        'dzikir': <int>[2101, 2104],
        'kajian live': <int>[2201],
        'pengingat kajian': <int>[2300, 2899],
        'tes adzan': <int>[2999],
      };

      for (final MapEntry<String, List<int>> baris in dipakaiLain.entries) {
        final int bawah = baris.value.first;
        final int atas = baris.value.last;
        for (final int nilai in id) {
          expect(
            nilai < bawah || nilai > atas,
            isTrue,
            reason: 'ID $nilai bertabrakan dengan ${baris.key} ($bawah–$atas)',
          );
        }
      }
    });

    test(
      'pengingat kajian dan pengingat runtutan tidak mungkin bertabrakan',
      () {
        // Dua fitur ini sama-sama memasang banyak notifikasi sekaligus, jadi
        // batasnya diperiksa langsung di sini juga.
        expect(NotificationService.idPengingatStreak(0), greaterThan(2899));

        final List<int> idKajian = <int>[
          for (int hari = 0; hari < 30; hari++)
            for (int urutan = 0; urutan < 20; urutan++)
              2300 + hari * 20 + urutan,
        ];
        final List<int> idStreak = <int>[
          for (int hari = 0; hari < 7; hari++)
            NotificationService.idPengingatStreak(hari),
        ];

        expect(idKajian.toSet().intersection(idStreak.toSet()), isEmpty);
      },
    );
  });
}
