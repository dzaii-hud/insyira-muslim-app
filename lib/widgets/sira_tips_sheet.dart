import 'package:flutter/material.dart';

import '../services/sira_pendamping.dart';
import '../services/tips_sira.dart';
import '../theme/app_theme.dart';
import 'sira_mascot.dart';

/// Membuka lembar tips dari Sira.
///
/// Bentuknya lembar bawah, sama seperti rincian kajian — bukan halaman baru,
/// supaya pengguna tidak kehilangan tempatnya di halaman yang sedang dibuka.
Future<void> bukaTipsSira(BuildContext context, TipsSira tips) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => SiraTipsSheet(tips: tips),
  );
}

class SiraTipsSheet extends StatelessWidget {
  const SiraTipsSheet({super.key, required this.tips});

  final TipsSira tips;

  @override
  Widget build(BuildContext context) {
    final Color latar = AppColors.getSurfaceContainerLow(context);
    final Color emas = AppColors.getGoldLeaf(context);
    final Color teks = AppColors.getTextPrimary(context);
    final Color redup = AppColors.getOnSurfaceVariant(context);

    return Container(
      decoration: BoxDecoration(
        color: latar,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Pegangan untuk menutup lembar.
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: redup.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                child: Row(
                  children: <Widget>[
                    const SiraMascot(
                      ukuran: 64,
                      ekspresi: SiraEkspresi.senang,
                      animasi: false,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Sira',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: emas,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tips.judul,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.25,
                              color: teks,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              for (final String poin in tips.poin)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Icon(
                          Icons.circle,
                          size: 7,
                          color: emas.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          poin,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.55,
                            color: teks,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color: AppColors.getSurfaceVariant(context),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 15,
                      color: redup,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Mau bertanya langsung? Obrolan dengan Sira sedang '
                        'disiapkan dan akan hadir di pembaruan berikutnya.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: redup,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: TextButton.icon(
                  onPressed: () => _sembunyikan(context),
                  icon: Icon(
                    Icons.visibility_off_rounded,
                    size: 17,
                    color: redup,
                  ),
                  label: Text(
                    'Sembunyikan Sira',
                    style: TextStyle(fontSize: 12.5, color: redup),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sembunyikan(BuildContext context) async {
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    await SiraPendamping.instance.setAktif(false);
    if (!navigator.mounted) return;
    navigator.pop();

    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Sira disembunyikan. Nyalakan lagi kapan saja di Pengaturan.',
        ),
      ),
    );
  }
}
