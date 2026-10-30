import 'package:flutter_test/flutter_test.dart';
import 'package:insyira_muslim_app/screens/kajian_screen.dart';

/// Menguji urutan daftar jadwal kajian.
///
/// Urutannya tidak terlihat salah di kode — hanya terasa salah saat dipakai.
/// Karena itu yang dijaga di sini adalah hasil akhirnya: kajian **paling baru**
/// harus berada di paling atas, bukan kajian paling lama.
void main() {
  Kajian buat(String tanggal, String jamMulai) => Kajian(
    tanggal: tanggal,
    judul: 'Kajian $tanggal $jamMulai',
    ustadz: 'Ustadz',
    jamMulai: jamMulai,
    jamSelesai: jamMulai,
    lokasi: 'Musholla Insyira',
  );

  test('kajian dengan tanggal terbaru berada di paling atas', () {
    final List<Kajian> daftar = <Kajian>[
      buat('2026-09-29', '09:15'),
      buat('2026-10-26', '08:00'),
      buat('2026-10-12', '10:00'),
    ];

    daftar.sort(Kajian.urutTerbaruDahulu);

    expect(
      daftar.map((Kajian k) => k.tanggal).toList(),
      <String>['2026-10-26', '2026-10-12', '2026-09-29'],
    );
  });

  test('pada tanggal yang sama, jam mulai terakhir di atas', () {
    final List<Kajian> daftar = <Kajian>[
      buat('2026-10-20', '08:00'),
      buat('2026-10-20', '16:30'),
    ];

    daftar.sort(Kajian.urutTerbaruDahulu);

    expect(daftar.first.jamMulai, '16:30');
  });
}
