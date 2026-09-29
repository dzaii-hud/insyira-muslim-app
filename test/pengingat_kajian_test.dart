import 'package:flutter_test/flutter_test.dart';
import 'package:insyira_muslim_app/services/notification_service.dart';

/// Tes penjaga untuk **pengingat jadwal kajian**.
///
/// Aturan yang dijaga di sini — hasil keputusan user 29 Sep 2026:
/// setiap kajian yang akan datang mendapat DUA pengingat, yaitu
/// [NotificationService.menitPengingatKajian] menit sebelum jam mulai dan
/// tepat saat jam mulai. Keduanya dipasang pada TANGGAL & JAM persis
/// (bukan jam tetap yang diulang), karena tiap kajian jamnya berbeda.
void main() {
  /// Sengaja dipatok supaya hasil tes tidak berubah tergantung jam berapa tes
  /// dijalankan, dan supaya hasilnya sama di mesin mana pun.
  final sekarang = DateTime(2026, 9, 29, 12, 0);

  KajianRingkas kajian(
    DateTime mulai, {
    String judul = 'Kajian Uji',
    String ustadz = 'Ustadz Uji',
    String lokasi = 'Mushola Insyira',
  }) =>
      KajianRingkas(mulai: mulai, judul: judul, ustadz: ustadz, lokasi: lokasi);

  List<PengingatKajian> rencana(List<KajianRingkas> daftar) =>
      NotificationService.rencanaPengingatKajian(daftar, sekarang: sekarang);

  test('tiap kajian dapat DUA pengingat: H-30 menit dan saat jam mulai', () {
    final hasil = rencana([kajian(DateTime(2026, 9, 29, 18, 45))]);

    expect(hasil.length, 2);

    final h30 = hasil.firstWhere((p) => p.jenis == JenisPengingatKajian.h30);
    final mulai = hasil.firstWhere(
      (p) => p.jenis == JenisPengingatKajian.mulai,
    );

    expect(
      h30.waktu,
      DateTime(2026, 9, 29, 18, 15),
      reason:
          'pengingat pertama harus tepat ${NotificationService.menitPengingatKajian} '
          'menit sebelum jam mulai',
    );
    expect(mulai.waktu, DateTime(2026, 9, 29, 18, 45));
  });

  test(
    'jam pengingat mengikuti jadwal tiap kajian, bukan satu jam yang disalin',
    () {
      final hasil = rencana([
        kajian(DateTime(2026, 9, 29, 18, 45), judul: 'Kajian A'),
        kajian(DateTime(2026, 10, 2, 20, 0), judul: 'Kajian B'),
        kajian(DateTime(2026, 10, 2, 5, 30), judul: 'Kajian C'),
      ]);

      final jamMulai = hasil
          .where((p) => p.jenis == JenisPengingatKajian.mulai)
          .map((p) => p.waktu)
          .toList();

      expect(jamMulai, hasLength(3));
      expect(jamMulai, contains(DateTime(2026, 9, 29, 18, 45)));
      expect(jamMulai, contains(DateTime(2026, 10, 2, 20, 0)));
      expect(jamMulai, contains(DateTime(2026, 10, 2, 5, 30)));
    },
  );

  test('pengingat H-30 dan saat mulai diperiksa TERPISAH, bukan sekaligus', () {
    // Kajian 10 menit lagi: pengingat H-30 sudah lewat (11:40), tapi
    // pengingat saat mulai masih harus dipasang — justru itu yang paling
    // dibutuhkan user saat itu.
    final hasil = rencana([kajian(DateTime(2026, 9, 29, 12, 10))]);

    expect(hasil, hasLength(1));
    expect(hasil.single.jenis, JenisPengingatKajian.mulai);
    expect(hasil.single.waktu, DateTime(2026, 9, 29, 12, 10));
  });

  test('kajian yang sudah lewat dan yang di luar 30 hari tidak dipasang', () {
    final hasil = rencana([
      kajian(DateTime(2026, 9, 29, 9, 0), judul: 'Sudah lewat'),
      kajian(DateTime(2026, 9, 28, 18, 0), judul: 'Kemarin'),
      // Hari ke-31 (batasnya 30 hari ke depan = s/d 28 Okt).
      kajian(DateTime(2026, 10, 29, 18, 0), judul: 'Terlalu jauh'),
    ]);

    expect(hasil, isEmpty);
  });

  test('kajian pada hari ke-29 masih dipasang, hari ke-30 tidak', () {
    // hariKajianKeDepan = 30 berarti hari ke-0 sampai hari ke-29.
    final hasil = rencana([
      kajian(DateTime(2026, 10, 28, 18, 0), judul: 'Hari ke-29'),
      kajian(DateTime(2026, 10, 29, 18, 0), judul: 'Hari ke-30'),
    ]);

    final judul = hasil.map((p) => p.kajian.judul).toSet();
    expect(judul, contains('Hari ke-29'));
    expect(judul, isNot(contains('Hari ke-30')));
  });

  test('semua pengingat berada di masa depan', () {
    final hasil = rencana([
      kajian(DateTime(2026, 9, 29, 18, 45)),
      kajian(DateTime(2026, 10, 2, 20, 0)),
      kajian(DateTime(2026, 9, 29, 12, 10)),
    ]);

    for (final pengingat in hasil) {
      expect(
        pengingat.waktu.isAfter(sekarang),
        isTrue,
        reason:
            'pengingat ${pengingat.kajian.judul} (${pengingat.jenis.name}) '
            'sudah lewat',
      );
    }
  });

  test(
    'setiap pengingat punya ID unik dan tidak bentrok dengan notifikasi lain',
    () {
      final hasil = rencana([
        kajian(DateTime(2026, 9, 29, 18, 45), judul: 'Kajian A'),
        kajian(DateTime(2026, 10, 2, 20, 0), judul: 'Kajian B'),
        kajian(DateTime(2026, 10, 2, 5, 30), judul: 'Kajian C'),
      ]);

      final id = hasil.map((p) => p.id).toList();
      expect(
        id.toSet().length,
        id.length,
        reason: 'ada ID pengingat yang kembar',
      );

      // ID notifikasi lain di aplikasi ini — jangan sampai tertabrak.
      const List<int> idTerpakai = <int>[
        2101, 2102, 2103, 2104, // dzikir
        2201, // kabar kajian live
        2999, // tombol Tes Adzan
      ];

      for (final nilai in id) {
        expect(
          nilai,
          isNot(anyOf(idTerpakai)),
          reason: 'ID $nilai dipakai notifikasi lain',
        );

        // Rentang pengingat kajian: 2300–2899 (lihat _kajianIdDasar).
        // Di bawah 2300 = menabrak kajian live, di atas 2899 = mendekati
        // tombol Tes Adzan.
        expect(nilai, greaterThanOrEqualTo(2300));
        expect(nilai, lessThan(2900));
      }

      // Jangan sampai menabrak blok adzan (1100–1604) juga.
      for (final nilai in id) {
        expect(nilai, isNot(inInclusiveRange(1100, 1604)));
      }
    },
  );

  test('ID pengingat stabil untuk daftar yang sama', () {
    final daftar = [
      kajian(DateTime(2026, 9, 29, 18, 45), judul: 'Kajian A'),
      kajian(DateTime(2026, 10, 2, 20, 0), judul: 'Kajian B'),
    ];

    final pertama = rencana(daftar).map((p) => '${p.id}:${p.jenis.name}');
    final kedua = rencana(daftar).map((p) => '${p.id}:${p.jenis.name}');

    expect(pertama, orderedEquals(kedua));
  });

  test('urutan daftar dari API tidak mengubah hasil', () {
    final a = kajian(DateTime(2026, 10, 2, 20, 0), judul: 'Kajian B');
    final b = kajian(DateTime(2026, 9, 29, 18, 45), judul: 'Kajian A');

    final urut = rencana([a, b]).map((p) => p.id).toList();
    final terbalik = rencana([b, a]).map((p) => p.id).toList();

    expect(urut, orderedEquals(terbalik));
  });

  test('kalau sehari lebih dari 10 kajian, kelebihannya tidak dipasang', () {
    // Batas 10 per hari ada supaya ID tidak melimpah keluar rentangnya.
    final hasil = rencana([
      for (int i = 0; i < 14; i++)
        kajian(
          DateTime(2026, 10, 2, 13, 0).add(Duration(minutes: i * 10)),
          judul: 'Kajian ke-$i',
        ),
    ]);

    expect(hasil.length, 10 * 2);

    for (final pengingat in hasil) {
      expect(pengingat.id, lessThan(2900));
    }
  });

  test('KajianRingkas.dariMap membaca bentuk API yang sebenarnya', () {
    // Bentuk yang benar-benar dikirim `/api/kajian`:
    // tanggal bisa memuat jam (`T...Z`) dan jam_mulai bisa memuat detik.
    final hasil = KajianRingkas.dariMap(<String, dynamic>{
      'tanggal': '2026-09-22T00:00:00.000000Z',
      'jam_mulai': '18:45:00',
      'judul': 'Nabi Adam : Antara Kemulian Dan Ujian',
      'ustadz': 'Ustadz Uji',
      'lokasi': 'Mushola Insyira',
    });

    expect(hasil, isNotNull);
    expect(hasil!.mulai, DateTime(2026, 9, 22, 18, 45));
    expect(hasil.judul, 'Nabi Adam : Antara Kemulian Dan Ujian');
    expect(hasil.lokasi, 'Mushola Insyira');
  });

  test('KajianRingkas.dariMap menolak data yang tanggalnya tidak terbaca', () {
    // Satu data rusak tidak boleh menggagalkan seluruh penjadwalan.
    expect(
      KajianRingkas.dariMap(<String, dynamic>{
        'tanggal': '',
        'jam_mulai': '18:45',
      }),
      isNull,
    );
    expect(
      KajianRingkas.dariMap(<String, dynamic>{
        'tanggal': 'bukan tanggal',
        'jam_mulai': '18:45',
      }),
      isNull,
    );
  });

  test('KajianRingkas bertahan setelah disimpan dan dibaca ulang', () {
    final asli = kajian(DateTime(2026, 9, 29, 18, 45), judul: 'Kajian Simpan');
    final lagi = KajianRingkas.dariJsonTersimpan(asli.toJson());

    expect(lagi, isNotNull);
    expect(lagi!.mulai, asli.mulai);
    expect(lagi.judul, asli.judul);
    expect(lagi.ustadz, asli.ustadz);
    expect(lagi.lokasi, asli.lokasi);
  });

  test('bekerja pada jawaban ASLI /api/kajian (salinan 29 Sep 2026)', () {
    // Salinan apa adanya dari produksi, sengaja TIDAK diringkas supaya bentuk
    // aslinya (tanggal berakhiran `Z`, jam berisi detik, teks Arab pada nama
    // ustadz, nama berkas foto) tetap terjaga kalau backend berubah bentuk.
    final jawaban = [
      <String, dynamic>{
        'id': 2,
        'judul': 'kitab al bidayah wa an nihayah',
        'ustadz': "Ustadz Dr Muamar Ma'ruf MA. حفظه اللّه",
        'tanggal': '2026-09-29T00:00:00.000000Z',
        'jam_mulai': '09:15:00',
        'jam_selesai': '11:15:00',
        'lokasi': 'mushalla insyira',
        'foto_ustadz':
            'foto_ustadz/gr6LlhTh6wfjyPhtt6mtErUGJruWZbtS4pjEdZmU.jpg',
        'foto_ustadz_url':
            'https://api.pusatoleolehpekanbaru.id/api/foto/gr6LlhTh6wfjyPhtt6mtErUGJruWZbtS4pjEdZmU.jpg',
      },
      <String, dynamic>{
        'id': 3,
        'judul': 'Nabi Adam : Antara Kemulian Dan Ujian (Bagian 3)',
        'ustadz': 'Syaikh Dr. Abul Hasan Ali Bin Jadullah  حفظه اللّه',
        'tanggal': '2026-09-29T00:00:00.000000Z',
        'jam_mulai': '18:30:00',
        'jam_selesai': '20:00:00',
        'lokasi': 'mushalla insyira',
        'foto_ustadz':
            'foto_ustadz/1DxIZTxIAnwyhJaxfLsBrOjH3dYVR8aDeOByEcK8.jpg',
        'foto_ustadz_url':
            'https://api.pusatoleolehpekanbaru.id/api/foto/1DxIZTxIAnwyhJaxfLsBrOjH3dYVR8aDeOByEcK8.jpg',
      },
    ];

    final daftar = jawaban
        .map(KajianRingkas.dariMap)
        .whereType<KajianRingkas>()
        .toList();

    expect(daftar, hasLength(2), reason: 'kedua data harus terbaca');
    expect(daftar.first.mulai, DateTime(2026, 9, 29, 9, 15));
    expect(daftar.last.mulai, DateTime(2026, 9, 29, 18, 30));
    expect(daftar.last.lokasi, 'mushalla insyira');

    // Pada pukul 12:00 hari itu: kajian 09:15 sudah lewat (tidak dipasang),
    // kajian 18:30 belum — pengingatnya 18:00 dan 18:30.
    final hasil = rencana(daftar);

    expect(hasil.map((p) => p.kajian.judul).toSet(), <String>{
      'Nabi Adam : Antara Kemulian Dan Ujian (Bagian 3)',
    });
    expect(hasil.map((p) => p.waktu).toList()..sort(), <DateTime>[
      DateTime(2026, 9, 29, 18, 0),
      DateTime(2026, 9, 29, 18, 30),
    ]);
  });
}
