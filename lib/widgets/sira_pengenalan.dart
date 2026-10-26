import 'package:flutter/material.dart';

import '../services/sira_pendamping.dart';
import '../theme/app_theme.dart';
import 'sira_mascot.dart';

/// Menampilkan perkenalan Sira untuk pengguna baru.
///
/// Dipanggil sekali, saat pengguna pertama kali sampai di beranda. Sengaja
/// tidak bisa ditutup dengan menggeser ke bawah atau mengetuk area gelap:
/// kalau bisa, orang akan menutupnya tanpa membaca — dan maskot yang muncul
/// tanpa penjelasan justru membingungkan. Jalan keluarnya jelas: tombol
/// "Lewati" di kanan atas.
Future<void> bukaPengenalanSira(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => const SiraPengenalan(),
  );
}

class SiraPengenalan extends StatefulWidget {
  const SiraPengenalan({super.key});

  @override
  State<SiraPengenalan> createState() => _SiraPengenalanState();
}

class _SiraPengenalanState extends State<SiraPengenalan> {
  final PageController _halaman = PageController();
  int _indeks = 0;

  static const List<_HalamanPengenalan> _isi = <_HalamanPengenalan>[
    _HalamanPengenalan(
      ikon: null,
      judul: 'Kenalan dulu, yuk',
      cerita:
          'Aku Sira, lentera kecil yang menemani kamu di Insyira. '
          'Tugasku satu: memastikan kamu tidak tersesat di dalam aplikasi.',
    ),
    _HalamanPengenalan(
      ikon: Icons.open_with_rounded,
      judul: 'Geser aku ke mana saja',
      cerita:
          'Tarik aku ke pojok mana pun yang paling nyaman. Aku akan diam '
          'di situ dan mengingatnya, jadi kamu tidak perlu menggeser lagi '
          'setiap kali membuka aplikasi.',
    ),
    _HalamanPengenalan(
      ikon: Icons.touch_app_rounded,
      judul: 'Ketuk aku kalau bingung',
      cerita:
          'Aku tahu kamu sedang di halaman mana, jadi yang kujelaskan '
          'selalu yang sedang kamu lihat — tanpa perlu keluar dari halaman '
          'itu.',
    ),
    _HalamanPengenalan(
      ikon: Icons.forum_rounded,
      judul: 'Nanti bisa diajak ngobrol',
      cerita:
          'Sedang kusiapkan: kamu bisa bertanya bebas tentang aplikasi ini. '
          'Untuk sekarang, tips singkat dariku dulu, ya.',
    ),
  ];

  @override
  void dispose() {
    _halaman.dispose();
    super.dispose();
  }

  Future<void> _selesai() async {
    final NavigatorState navigator = Navigator.of(context);
    await SiraPendamping.instance.tandaiPengenalanSelesai();
    if (!navigator.mounted) return;
    if (navigator.canPop()) navigator.pop();
  }

  void _lanjut() {
    if (_indeks >= _isi.length - 1) {
      _selesai();
      return;
    }

    _halaman.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;
    final Color emas = AppColors.getGoldLeaf(context);
    final Color teks = gelap ? Colors.white : const Color(0xFF0B231B);
    final Color redup = gelap
        ? Colors.white.withValues(alpha: 0.68)
        : const Color(0xFF3F5B50);

    final bool terakhir = _indeks >= _isi.length - 1;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.92,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gelap
              ? const <Color>[Color(0xFF00372A), Color(0xFF00120B)]
              : const <Color>[Color(0xFFF3FAF6), Color(0xFFDCEBE3)],
        ),
      ),
      child: Column(
        children: <Widget>[
          // Tombol lewati — satu-satunya jalan keluar selain menyelesaikan.
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 12, right: 8),
              child: TextButton(
                onPressed: _selesai,
                child: Text(
                  'Lewati',
                  style: TextStyle(color: redup, fontSize: 13),
                ),
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _halaman,
              itemCount: _isi.length,
              onPageChanged: (int i) => setState(() => _indeks = i),
              itemBuilder: (BuildContext context, int i) {
                final _HalamanPengenalan h = _isi[i];

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 190,
                        child: Center(
                          child: h.ikon == null
                              ? const SiraMascot(
                                  ukuran: 150,
                                  ekspresi: SiraEkspresi.senang,
                                )
                              : Container(
                                  width: 128,
                                  height: 128,
                                  decoration: BoxDecoration(
                                    color: emas.withValues(alpha: 0.14),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: emas.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Icon(h.ikon, size: 56, color: emas),
                                ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      Text(
                        h.judul,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                          color: teks,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        h.cerita,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.65,
                          color: redup,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Titik penanda halaman.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (int i = 0; i < _isi.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _indeks ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _indeks ? emas : emas.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: emas,
                  foregroundColor: const Color(0xFF00120B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _lanjut,
                child: Text(
                  terakhir ? 'Mulai pakai Insyira' : 'Lanjut',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
            child: Text(
              'Tidak suka ditemani? Tekan lama Sira kapan saja untuk '
              'mematikannya.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, height: 1.5, color: redup),
            ),
          ),
        ],
      ),
    );
  }
}

class _HalamanPengenalan {
  const _HalamanPengenalan({
    required this.ikon,
    required this.judul,
    required this.cerita,
  });

  /// `null` berarti halaman ini menampilkan Sira sendiri, bukan ikon.
  final IconData? ikon;
  final String judul;
  final String cerita;
}
