import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tes penjaga untuk bug yang pernah lolos ke tester:
/// kartu "SHALAT SELANJUTNYA" di layar utama macet menampilkan "Memuat..."
/// sepanjang malam (dilaporkan 22 Sep 2026, sesudah waktu Isya).
///
/// Sebabnya: `PrayerTimes.nextPrayer()` mengembalikan [Prayer.none] begitu
/// SELURUH sholat hari itu terlewat. Perbaikannya ada di
/// `lib/screens/home_screen.dart` -> `_hitungSholatBerikutnya()` yang menghitung
/// jadwal BESOK dan memakai Subuh. Tes ini menjaga asumsi di balik perbaikan itu
/// supaya tidak diam-diam berubah kalau paket `adhan` diperbarui.
void main() {
  final koordinat = Coordinates(0.5071, 101.4478); // Pekanbaru
  CalculationParameters parameter() {
    final p = CalculationMethod.singapore.getParameters();
    p.madhab = Madhab.shafi;
    return p;
  }

  test('setelah Isya, nextPrayer() memang bernilai Prayer.none', () {
    final jadwal = PrayerTimes(
      koordinat,
      DateComponents.from(DateTime(2026, 9, 22)),
      parameter(),
    );
    final sesudahIsya = jadwal.isha.add(const Duration(minutes: 30));

    expect(
      jadwal.nextPrayerByDateTime(sesudahIsya),
      Prayer.none,
      reason:
          'Kalau ini berubah, _hitungSholatBerikutnya() perlu ditinjau ulang.',
    );
  });

  test('jadwal untuk tanggal besok memberi Subuh BESOK, bukan hari ini', () {
    final tanggalIni = DateTime(2026, 9, 22);
    final sesudahIsya = DateTime(2026, 9, 22, 19, 30);

    final jadwalIni = PrayerTimes(
      koordinat,
      DateComponents.from(tanggalIni),
      parameter(),
    );
    final jadwalBesok = PrayerTimes(
      koordinat,
      DateComponents.from(sesudahIsya.add(const Duration(days: 1))),
      parameter(),
    );

    // Inilah yang dipakai kartu di layar utama: kalau nextPrayer() = Prayer.none,
    // ambil Subuh dari jadwal besok.
    expect(jadwalIni.nextPrayerByDateTime(sesudahIsya), Prayer.none);

    final subuhBesok = jadwalBesok.timeForPrayer(Prayer.fajr);
    expect(subuhBesok, isNotNull);
    expect(
      subuhBesok!.isAfter(sesudahIsya),
      isTrue,
      reason:
          'Waktu target harus di masa depan, kalau tidak hitungan mundur minus.',
    );
    expect(
      DateUtilsSameDay(subuhBesok, sesudahIsya.add(const Duration(days: 1))),
      isTrue,
      reason: 'Subuh yang dipakai harus tanggal 23 Sep, bukan 22 Sep.',
    );
    expect(jadwalBesok.fajr.isAfter(jadwalIni.fajr), isTrue);
  });
}

/// Pembanding tanggal tanpa bergantung pada Flutter (tes ini murni Dart).
bool DateUtilsSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
