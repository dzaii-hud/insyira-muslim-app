import 'package:flutter_test/flutter_test.dart';
import 'package:insyira_muslim_app/services/dzikir_service.dart';

/// Tes penjaga untuk **batas waktu dzikir**.
///
/// Keputusan pemilik aplikasi (1 Okt 2026): dzikir pagi hanya dihitung sampai
/// pukul 11:00, dzikir petang sampai pukul 18:00. Setelah lewat, hitungannya
/// dimatikan (teksnya masih boleh dibaca) dan kalau user tetap menekan muncul
/// pesan.
///
/// Batasnya EKSKLUSIF: tepat pukul 11:00 sudah dianggap lewat, karena
/// "sampai jam 11" berakhir saat jam 11 mulai.
void main() {
  test('dzikir pagi berlaku sampai sebelum pukul 11:00', () {
    expect(
      DzikirWaktu.masihDalamWaktu(
        isPagi: true,
        sekarang: DateTime(2026, 10, 1, 10, 59),
      ),
      isTrue,
    );
    expect(
      DzikirWaktu.masihDalamWaktu(
        isPagi: true,
        sekarang: DateTime(2026, 10, 1, 11, 0),
      ),
      isFalse,
      reason: 'tepat pukul 11:00 sudah lewat',
    );
    expect(
      DzikirWaktu.masihDalamWaktu(
        isPagi: true,
        sekarang: DateTime(2026, 10, 1, 23, 59),
      ),
      isFalse,
    );
  });

  test('dzikir petang berlaku sampai sebelum pukul 18:00', () {
    expect(
      DzikirWaktu.masihDalamWaktu(
        isPagi: false,
        sekarang: DateTime(2026, 10, 1, 17, 59),
      ),
      isTrue,
    );
    expect(
      DzikirWaktu.masihDalamWaktu(
        isPagi: false,
        sekarang: DateTime(2026, 10, 1, 18, 0),
      ),
      isFalse,
      reason: 'tepat pukul 18:00 sudah lewat',
    );
  });

  test('pagi tertutup lebih dulu daripada petang', () {
    // Pukul 12:00: sesi pagi sudah tutup, petang masih buka.
    final DateTime siang = DateTime(2026, 10, 1, 12, 0);
    expect(DzikirWaktu.masihDalamWaktu(isPagi: true, sekarang: siang), isFalse);
    expect(DzikirWaktu.masihDalamWaktu(isPagi: false, sekarang: siang), isTrue);
  });

  test('pagi masih dianggap terbuka sejak dini hari (hanya batas akhir)', () {
    expect(
      DzikirWaktu.masihDalamWaktu(
        isPagi: true,
        sekarang: DateTime(2026, 10, 1, 0, 1),
      ),
      isTrue,
    );
  });

  test('batas dihitung ulang tiap hari, bukan menempel di tanggal pertama', () {
    expect(
      DzikirWaktu.batas(isPagi: true, pada: DateTime(2026, 10, 1, 3, 0)),
      DateTime(2026, 10, 1, 11, 0),
    );
    expect(
      DzikirWaktu.batas(isPagi: false, pada: DateTime(2026, 12, 31, 23, 0)),
      DateTime(2026, 12, 31, 18, 0),
    );
  });

  test('pesan dan label waktunya sesuai batas masing-masing sesi', () {
    expect(DzikirWaktu.labelBatas(isPagi: true), '11:00');
    expect(DzikirWaktu.labelBatas(isPagi: false), '18:00');

    // Bunyi pesannya diminta persis begini oleh pemilik aplikasi.
    expect(
      DzikirWaktu.pesanLewat(isPagi: true),
      'Afwan, waktu dzikir pagi sudah lewat, '
      'jangan lupa untuk berdzikir besok yaa',
    );
    expect(
      DzikirWaktu.pesanLewat(isPagi: false),
      contains('waktu dzikir petang sudah lewat'),
    );

    expect(
      DzikirWaktu.keteranganBerlaku(isPagi: true),
      contains('sampai 11:00'),
    );
    expect(
      DzikirWaktu.keteranganBerlaku(isPagi: false),
      contains('sampai 18:00'),
    );
  });
}
