import 'dart:async';

import 'package:flutter/material.dart';

import '../services/sira_obrolan.dart';
import '../services/sira_pendamping.dart';
import '../theme/app_theme.dart';
import 'sira_mascot.dart';

/// Membuka obrolan dengan Sira.
///
/// Ditampilkan sebagai lembar penuh dari bawah, bukan dialog: obrolan bisa
/// panjang, butuh papan tombol, dan harus bisa digulir. Selama lembar ini
/// terbuka, [SiraPendamping.adaLapisanDiAtas] bernilai benar — jadi gelembung
/// Sira yang melayang ikut menghilang dan tidak menutupi percakapan.
Future<void> bukaObrolanSira(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => const SiraObrolanSheet(),
  );
}

/// Satu baris percakapan.
class _Pesan {
  _Pesan({required this.teks, required this.dariSira, this.saran = const <String>[]});

  final String teks;
  final bool dariSira;

  /// Pertanyaan lanjutan yang ditawarkan setelah pesan ini.
  final List<String> saran;
}

class SiraObrolanSheet extends StatefulWidget {
  const SiraObrolanSheet({super.key, this.otak});

  /// Otak obrolan. Boleh diganti di tes supaya jawabannya pasti.
  final SiraObrolan? otak;

  @override
  State<SiraObrolanSheet> createState() => _SiraObrolanSheetState();
}

class _SiraObrolanSheetState extends State<SiraObrolanSheet> {
  final List<_Pesan> _pesan = <_Pesan>[];
  final TextEditingController _kendali = TextEditingController();
  final ScrollController _gulir = ScrollController();
  final FocusNode _fokus = FocusNode();

  late final SiraObrolan _otak = widget.otak ?? SiraObrolan.bawaan;

  bool _siraMenulis = false;

  @override
  void initState() {
    super.initState();
    // Sapaan langsung tampil tanpa jeda: pengguna baru membuka lembar dan
    // harus langsung tahu siapa yang diajak bicara serta sedang di halaman apa.
    unawaited(_mulai());
  }

  @override
  void dispose() {
    _kendali.dispose();
    _gulir.dispose();
    _fokus.dispose();
    super.dispose();
  }

  KonteksSira get _konteks => KonteksSira(
    halaman: SiraPendamping.instance.namaHalaman.value,
    tabHome: SiraPendamping.instance.tabHome.value,
  );

  Future<void> _mulai() async {
    final BalasanSira balasan = await _otak.jawab('', konteks: _konteks);
    if (!mounted) return;
    setState(() {
      _pesan.add(
        _Pesan(teks: balasan.teks, dariSira: true, saran: balasan.saran),
      );
    });
  }

  Future<void> _kirim(String teks) async {
    final String isi = teks.trim();
    if (isi.isEmpty || _siraMenulis) return;

    setState(() {
      _pesan.add(_Pesan(teks: isi, dariSira: false));
      _siraMenulis = true;
    });
    _kendali.clear();
    _gulirKeBawah();

    // Jeda sependek ini cukup supaya percakapan terasa dijawab, bukan
    // ditempel — dan memberi waktu daftar bergulir ke pesan terbaru.
    await Future<void>.delayed(const Duration(milliseconds: 380));

    final BalasanSira balasan = await _otak.jawab(isi, konteks: _konteks);
    if (!mounted) return;

    setState(() {
      _pesan.add(
        _Pesan(teks: balasan.teks, dariSira: true, saran: balasan.saran),
      );
      _siraMenulis = false;
    });
    _gulirKeBawah();
  }

  void _gulirKeBawah() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_gulir.hasClients) return;
      _gulir.animateTo(
        _gulir.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color latar = AppColors.getSurfaceContainerLow(context);
    final Color emas = AppColors.getGoldLeaf(context);

    return AnimatedPadding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.88,
        decoration: BoxDecoration(
          color: latar,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(color: emas.withValues(alpha: 0.25)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              _kepala(context, emas),
              Expanded(
                child: ListView.builder(
                  controller: _gulir,
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                  itemCount: _pesan.length + (_siraMenulis ? 1 : 0),
                  itemBuilder: (BuildContext context, int i) {
                    if (i >= _pesan.length) return _indikatorMenulis(context, emas);

                    final _Pesan pesan = _pesan[i];
                    final bool terakhir = i == _pesan.length - 1;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _gelembung(context, pesan, emas),
                        if (terakhir && pesan.dariSira && pesan.saran.isNotEmpty)
                          _saran(context, pesan.saran, emas),
                      ],
                    );
                  },
                ),
              ),
              _kolomKetik(context, emas),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================================
  // BAGIAN ATAS
  // =====================================================================
  Widget _kepala(BuildContext context, Color emas) {
    final Color teks = AppColors.getTextPrimary(context);
    final Color redup = AppColors.getOnSurfaceVariant(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: emas.withValues(alpha: 0.18)),
        ),
      ),
      child: Row(
        children: <Widget>[
          const SiraMascot(ukuran: 38, animasi: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Obrolan dengan Sira',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: teks,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tahu kamu di halaman ${_konteks.judulHalaman}',
                  style: TextStyle(fontSize: 11.5, color: redup),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tutup obrolan',
            icon: Icon(Icons.close_rounded, color: redup, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // GELEMBUNG PESAN
  // =====================================================================
  Widget _gelembung(BuildContext context, _Pesan pesan, Color emas) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;
    final Color teks = AppColors.getTextPrimary(context);

    final Color warna = pesan.dariSira
        ? AppColors.getSurfaceVariant(context)
        : emas;
    final Color warnaTeks = pesan.dariSira
        ? teks
        : (gelap ? const Color(0xFF00120B) : Colors.white);

    final Widget balon = Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: warna,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(pesan.dariSira ? 4 : 16),
          bottomRight: Radius.circular(pesan.dariSira ? 16 : 4),
        ),
        border: pesan.dariSira
            ? Border.all(color: emas.withValues(alpha: 0.22))
            : null,
      ),
      child: Text(
        pesan.teks,
        style: TextStyle(fontSize: 13.5, height: 1.55, color: warnaTeks),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: pesan.dariSira
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (pesan.dariSira) ...<Widget>[
            const Padding(
              padding: EdgeInsets.only(top: 2, right: 8),
              child: SiraMascot(ukuran: 24, animasi: false),
            ),
          ],
          Flexible(child: balon),
        ],
      ),
    );
  }

  Widget _saran(BuildContext context, List<String> saran, Color emas) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 32),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final String teks in saran)
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => unawaited(_kirim(teks)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: emas.withValues(alpha: 0.45)),
                ),
                child: Text(
                  teks,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _indikatorMenulis(BuildContext context, Color emas) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: <Widget>[
          const SiraMascot(ukuran: 24, animasi: false),
          const SizedBox(width: 8),
          Text(
            'Sira sedang menulis…',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: emas.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // KOLOM KETIK
  // =====================================================================
  Widget _kolomKetik(BuildContext context, Color emas) {
    final Color redup = AppColors.getOnSurfaceVariant(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: emas.withValues(alpha: 0.18)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _kendali,
              focusNode: _fokus,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (String nilai) => unawaited(_kirim(nilai)),
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.getTextPrimary(context),
              ),
              cursorColor: emas,
              decoration: InputDecoration(
                hintText: 'Tanya Sira apa saja…',
                hintStyle: TextStyle(fontSize: 13, color: redup),
                filled: true,
                fillColor: AppColors.getSurfaceVariant(context).withValues(
                  alpha: 0.5,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: emas.withValues(alpha: 0.22)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: emas.withValues(alpha: 0.6)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Kirim',
            onPressed: _siraMenulis
                ? null
                : () => unawaited(_kirim(_kendali.text)),
            icon: Icon(
              Icons.send_rounded,
              color: _siraMenulis ? redup.withValues(alpha: 0.4) : emas,
            ),
          ),
        ],
      ),
    );
  }
}
