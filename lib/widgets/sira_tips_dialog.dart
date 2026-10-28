import 'package:flutter/material.dart';

import '../services/sira_pendamping.dart';
import '../services/tips_sira.dart';
import '../theme/app_theme.dart';
import 'gulungan_kertas.dart';
import 'sira_mascot.dart';

/// Membuka tips Sira di TENGAH layar, seperti gulungan kertas yang dibuka.
///
/// Bukan lembar dari bawah: tips ini pendek dan berdiri sendiri — tidak perlu
/// menutupi bagian bawah layar yang sedang dibaca pengguna.
Future<void> bukaTipsSira(BuildContext context, TipsSira tips) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (BuildContext context) => SiraTipsDialog(tips: tips),
  );
}

class SiraTipsDialog extends StatefulWidget {
  const SiraTipsDialog({super.key, required this.tips});

  final TipsSira tips;

  @override
  State<SiraTipsDialog> createState() => _SiraTipsDialogState();
}

class _SiraTipsDialogState extends State<SiraTipsDialog> {
  @override
  Widget build(BuildContext context) {
    final Color latar = AppColors.getSurfaceContainerLow(context);
    final Color emas = AppColors.getGoldLeaf(context);
    final Color teks = AppColors.getTextPrimary(context);
    final Color redup = AppColors.getOnSurfaceVariant(context);
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: GulunganKertas(
          warnaRol: emas,
          child: Container(
            decoration: BoxDecoration(
              color: latar,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: emas.withValues(alpha: 0.35)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: gelap ? 0.5 : 0.18),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _kepala(context, emas, teks, redup),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (final String poin in widget.tips.poin)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
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
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 14,
                              color: redup,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Mau bertanya langsung? Obrolan dengan Sira '
                                'sedang disiapkan dan akan hadir di pembaruan '
                                'berikutnya.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.5,
                                  color: redup,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(
                  height: 24,
                  indent: 22,
                  endIndent: 22,
                  color: AppColors.getSurfaceVariant(context),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
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
      ),
    );
  }

  Widget _kepala(BuildContext context, Color emas, Color teks, Color redup) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SiraMascot(
            ukuran: 54,
            ekspresi: SiraEkspresi.senang,
            animasi: false,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Sira',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: emas,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.tips.judul,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                    color: teks,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded, size: 20, color: redup),
            tooltip: 'Tutup',
            visualDensity: VisualDensity.compact,
          ),
        ],
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
