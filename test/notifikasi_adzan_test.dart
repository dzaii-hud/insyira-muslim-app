import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insyira_muslim_app/services/notification_service.dart';

/// Tes penjaga untuk **ketepatan waktu adzan**.
///
/// ── Latar belakang (diukur 29 Sep 2026, Pekanbaru) ─────────────────────────
/// Dulu adzan dipasang sebagai SATU alarm berulang pada JAM TETAP. Karena
/// waktu sholat bergeser sedikit tiap hari, alarm itu menyimpang dari waktu
/// sebenarnya sampai **−10 s/d +40 menit** dalam setahun (Ashar paling parah) —
/// artinya adzan bisa berbunyi 40 menit SEBELUM masuk waktu.
///
/// Sekarang tiap hari dijadwalkan sendiri dengan jam HARI ITU, untuk 30 hari
/// ke depan. Tes ini menjaga sifat itu: kalau ada yang mengubahnya kembali
/// menjadi satu jam tetap yang berulang, tes ini gagal.
void main() {
  final koordinat = Coordinates(0.5071, 101.4478); // Pekanbaru
  final parameter = NotificationService.parameterSholat();

  PrayerTimes jadwalHari(DateTime t) =>
      PrayerTimes(koordinat, DateComponents.from(t), parameter);

  final awalHari = DateTime(2026, 9, 29);

  /// Sengaja dipatok supaya hasil tes tidak berubah tergantung jam berapa tes
  /// dijalankan. 20:00 = seluruh waktu sholat hari itu sudah lewat.
  final sekarang = DateTime(2026, 9, 29, 20, 0);

  test(
    'tiap hari memakai jam sholat HARI ITU, bukan jam tetap yang diulang',
    () {
      final rencana = NotificationService.rencanaJadwalAdzan(
        jadwalHari(awalHari),
        sekarang: sekarang,
      );

      final ashar = rencana.where((j) => j.namaWaktu == 'Ashar').toList();

      // Ashar HARI INI (15:10) sudah lewat karena `sekarang` = 20:00, jadi yang
      // terjadwal tinggal hari ke-1 sampai hari ke-29.
      expect(ashar.length, NotificationService.hariAdzanKeDepan - 1);
      expect(ashar.first.hariKe, 1);

      for (final jadwal in ashar) {
        final tanggalHariItu = awalHari.add(Duration(days: jadwal.hariKe));

        expect(
          jadwal.waktu,
          jadwalHari(tanggalHariItu).asr,
          reason:
              'Ashar hari ke-${jadwal.hariKe} harus memakai jam hari itu, '
              'bukan jam yang disalin dari hari pertama',
        );
      }

      // Buktikan jamnya MEMANG bergeser — kalau tidak, pemeriksaan di atas tidak
      // membuktikan apa pun (jam tetap pun akan lolos).
      final jamHariPertama = ashar.first.waktu;
      final jamHariTerakhirDisamakan = ashar.last.waktu.subtract(
        Duration(days: ashar.last.hariKe - ashar.first.hariKe),
      );

      expect(
        jamHariTerakhirDisamakan,
        isNot(jamHariPertama),
        reason: 'Ashar seharusnya bergeser sedikit dalam 30 hari',
      );
    },
  );

  test('semua alarm berada di masa depan dan tidak ada yang terlewat', () {
    final rencana = NotificationService.rencanaJadwalAdzan(
      jadwalHari(awalHari),
      sekarang: sekarang,
    );

    for (final jadwal in rencana) {
      expect(
        jadwal.waktu.isAfter(sekarang),
        isTrue,
        reason: '${jadwal.namaWaktu} hari ke-${jadwal.hariKe} sudah lewat',
      );
    }
  });

  test('waktu sholat hari ini yang sudah lewat tidak ikut dijadwalkan', () {
    final rencana = NotificationService.rencanaJadwalAdzan(
      jadwalHari(awalHari),
      sekarang: sekarang,
    );

    // 29 hari penuh × 5 waktu (hari ini sudah lewat semuanya pada 20:00).
    expect(
      rencana.length,
      (NotificationService.hariAdzanKeDepan - 1) *
          NotificationService.urutanWaktuSholat.length,
    );
    expect(rencana.any((j) => j.hariKe == 0), isFalse);
  });

  test(
    'setiap alarm punya ID unik dan tidak bentrok dengan notifikasi lain',
    () {
      final rencana = NotificationService.rencanaJadwalAdzan(
        jadwalHari(awalHari),
        sekarang: sekarang,
      );

      final id = rencana.map((j) => j.id).toList();
      expect(id.toSet().length, id.length, reason: 'ada ID adzan yang kembar');

      // ID notifikasi lain di aplikasi ini — jangan sampai tertabrak.
      const int idDzikirPagi = 2101;
      const int idDzikirSore = 2102;
      const int idPengingatDzikirPagi = 2103;
      const int idPengingatDzikirSore = 2104;
      const int idKajianLive = 2201;
      const int idTesAdzan = 2999;

      for (final nilai in id) {
        expect(
          nilai,
          isNot(
            anyOf(
              idDzikirPagi,
              idDzikirSore,
              idPengingatDzikirPagi,
              idPengingatDzikirSore,
              idKajianLive,
              idTesAdzan,
            ),
          ),
        );
      }
    },
  );

  test(
    'ID adzan yang ditampilkan langsung tidak bentrok dengan yang terjadwal',
    () {
      final rencana = NotificationService.rencanaJadwalAdzan(
        jadwalHari(awalHari),
        sekarang: sekarang,
      );
      final idTerjadwal = rencana.map((j) => j.id).toSet();

      for (int i = 0; i < NotificationService.urutanWaktuSholat.length; i++) {
        expect(
          idTerjadwal.contains(NotificationService.idAdzanLangsung(i)),
          isFalse,
        );
      }
    },
  );

  test('DOKUMENTASI: jam tetap memang menyimpang jauh — alasan tidak boleh '
      'kembali ke satu alarm berulang', () {
    final dasar = jadwalHari(awalHari).asr;
    var simpangTerbesar = 0;

    for (var hari = 0; hari <= 365; hari++) {
      final waktu = jadwalHari(awalHari.add(Duration(days: hari))).asr;
      final menitDasar = dasar.hour * 60 + dasar.minute;
      final menitNyata = waktu.hour * 60 + waktu.minute;
      final simpang = menitNyata - menitDasar;

      if (simpang.abs() > simpangTerbesar.abs()) simpangTerbesar = simpang;
    }

    // Kalau angka ini tiba-tiba kecil, berarti asumsi di balik perbaikan
    // (dan komentarnya) perlu ditinjau ulang.
    expect(
      simpangTerbesar.abs(),
      greaterThan(20),
      reason: 'Ashar seharusnya bergeser >20 menit dalam setahun',
    );
  });
}
