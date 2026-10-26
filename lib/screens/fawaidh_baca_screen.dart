import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_content.dart';

/// Halaman membaca satu fawaidh.
///
/// Dibuat terpisah dari daftarnya karena tujuannya berbeda: daftar untuk
/// memilih, halaman ini untuk **membaca**. Karena itu tipografinya dibuat
/// lapang (baris panjang tidak melelahkan), isinya bisa diblok untuk disalin
/// sebagian, dan ukuran hurufnya bisa dibesarkan.
///
/// Data awal bisa dititipkan lewat [awal] supaya halaman terbuka seketika
/// tanpa menunggu jaringan — misalnya saat diketuk dari daftar. Kalau
/// halaman ini dibuka langsung dari tautan (mis. di web), [awal] kosong dan
/// datanya diambil dari server berdasarkan [id].
class FawaidhBacaScreen extends StatefulWidget {
  const FawaidhBacaScreen({super.key, required this.id, this.awal});

  final int id;

  /// Data yang sudah ada di layar sebelumnya. Boleh kosong.
  final Map<String, dynamic>? awal;

  @override
  State<FawaidhBacaScreen> createState() => _FawaidhBacaScreenState();
}

class _FawaidhBacaScreenState extends State<FawaidhBacaScreen> {
  /// Nama bulan ditulis sendiri, tidak memakai paket tambahan hanya untuk
  /// satu keperluan format tanggal seperti ini.
  static const List<String> _namaBulan = <String>[
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static const double _skalaMinimum = 0.9;
  static const double _skalaMaksimum = 1.4;
  static const double _selisihSkala = 0.1;

  Map<String, dynamic>? _data;
  bool _memuat = true;
  String _galat = '';
  double _skala = 1.0;

  /// Pengendali gulir + penunjuk sejauh mana pembaca sudah berjalan.
  ///
  /// Penunjuknya memakai [ValueNotifier], bukan `setState`, supaya saat
  /// menggulir hanya bilah tipis di atas yang digambar ulang — bukan seluruh
  /// halaman. Halaman baca yang tersendat saat digulir justru merusak
  /// kenyamanan membacanya.
  final ScrollController _gulir = ScrollController();
  final ValueNotifier<double> _progres = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _gulir.addListener(_hitungProgres);

    if (widget.awal != null) {
      _data = widget.awal;
      _memuat = false;
    } else {
      _muat();
    }
  }

  @override
  void dispose() {
    _gulir.removeListener(_hitungProgres);
    _gulir.dispose();
    _progres.dispose();
    super.dispose();
  }

  void _hitungProgres() {
    if (!_gulir.hasClients) return;

    final double maks = _gulir.position.maxScrollExtent;

    // Tulisan yang muat di satu layar tidak perlu bilah sama sekali —
    // biarkan kosong daripada menampilkan "selesai" untuk teks dua baris.
    _progres.value = maks <= 0
        ? 0
        : (_gulir.position.pixels / maks).clamp(0.0, 1.0);
  }

  Future<void> _muat() async {
    setState(() {
      _memuat = true;
      _galat = '';
    });

    try {
      final http.Response jawaban = await http
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/fawaidh/${widget.id}'),
            headers: const <String, String>{'Accept': 'application/json'},
          )
          .timeout(AppConfig.requestTimeout);

      if (!mounted) return;

      if (jawaban.statusCode == 200) {
        final dynamic badan = json.decode(jawaban.body);
        if (badan is Map) {
          setState(() {
            _data = badan.cast<String, dynamic>();
            _memuat = false;
          });
          return;
        }
      }

      setState(() {
        _memuat = false;
        _galat = jawaban.statusCode == 404
            ? 'Fawaidh ini tidak ditemukan. Mungkin sudah dihapus pengurus.'
            : 'Tidak bisa memuat fawaidh (${jawaban.statusCode}).';
      });
    } catch (e) {
      debugPrint('Gagal memuat fawaidh: $e');
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _galat = 'Tidak bisa menghubungi server. Periksa koneksimu ya.';
      });
    }
  }

  void _ubahSkala(double selisih) {
    final double baru = (_skala + selisih).clamp(_skalaMinimum, _skalaMaksimum);

    if (baru != _skala) setState(() => _skala = baru);
  }

  void _salin() {
    final Map<String, dynamic>? data = _data;
    if (data == null) return;

    final String teks =
        '${data['judul'] ?? ''}\n\n'
        '${data['isi'] ?? ''}\n\n'
        '— ${data['penulis'] ?? 'Anonim'}';

    Clipboard.setData(ClipboardData(text: teks));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Fawaidh disalin ke clipboard',
          style: TextStyle(
            color: AppColors.getTextPrimary(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: AppColors.getSurfaceContainerLow(context),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  /// Mengubah tanggal ISO dari server menjadi "13 Oktober 2026".
  String _tanggal(Object? nilai) {
    final DateTime? waktu = DateTime.tryParse(nilai?.toString() ?? '');
    if (waktu == null) return '';

    final DateTime lokal = waktu.toLocal();

    return '${lokal.day} ${_namaBulan[lokal.month - 1]} ${lokal.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => popOrHome(context),
        ),
        title: Text(
          'Fawaidh',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.getPrimaryText(context),
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          // Ukuran huruf. Dua tombol kecil ini terasa sepele, tapi justru
          // inilah yang membuat halaman baca terasa nyaman untuk bacaan
          // panjang — terutama bagi pembaca yang matanya butuh huruf besar.
          IconButton(
            tooltip: 'Perkecil huruf',
            onPressed: _skala > _skalaMinimum
                ? () => _ubahSkala(-_selisihSkala)
                : null,
            icon: const Icon(Icons.text_decrease_rounded, size: 20),
          ),
          IconButton(
            tooltip: 'Perbesar huruf',
            onPressed: _skala < _skalaMaksimum
                ? () => _ubahSkala(_selisihSkala)
                : null,
            icon: const Icon(Icons.text_increase_rounded, size: 20),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            // Bilah kemajuan baca. Tipis saja — tugasnya memberi tahu
            // "sudah sejauh mana", bukan menarik perhatian.
            ValueListenableBuilder<double>(
              valueListenable: _progres,
              builder: (BuildContext context, double nilai, Widget? anak) {
                return SizedBox(
                  height: 2.5,
                  child: LinearProgressIndicator(
                    value: nilai,
                    backgroundColor: AppColors.getSurfaceVariant(context),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.getGoldLeaf(context),
                    ),
                  ),
                );
              },
            ),
            Expanded(child: ResponsiveContent(child: _buildIsi())),
          ],
        ),
      ),
    );
  }

  Widget _buildIsi() {
    if (_memuat) {
      return const Center(child: CircularProgressIndicator());
    }

    final Map<String, dynamic>? data = _data;

    if (data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.article_outlined,
                size: 34,
                color: AppColors.getOnSurfaceVariant(context),
              ),
              const SizedBox(height: 14),
              Text(
                _galat,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.getTextPrimary(context),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _muat,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final String judul = (data['judul'] ?? 'Tanpa Judul').toString();
    final String penulis = (data['penulis'] ?? 'Anonim').toString();
    final String isi = (data['isi'] ?? '').toString().trim();
    final String status = (data['status'] ?? '').toString();
    final String tanggal = _tanggal(data['created_at']);

    return SingleChildScrollView(
      controller: _gulir,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      child: _buildLembar(
        judul: judul,
        penulis: penulis,
        isi: isi,
        status: status,
        tanggal: tanggal,
      ),
    );
  }

  /// "Lembaran" tempat tulisan dibaca.
  ///
  /// Judul, penulis, dan isi diletakkan di dalam SATU kartu — bukan berserak
  /// di atas latar halaman. Ini yang membuat bacaan panjang terasa seperti
  /// satu lembar yang utuh: mata punya satu bidang yang jelas, dan tidak ada
  /// potongan teks yang mengambang tanpa tempat berpijak.
  Widget _buildLembar({
    required String judul,
    required String penulis,
    required String isi,
    required String status,
    required String tanggal,
  }) {
    final Color emas = AppColors.getGoldLeaf(context);
    final Color teks = AppColors.getTextPrimary(context);
    final Color redup = AppColors.getOnSurfaceVariant(context);
    final bool gelap = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceContainerLow(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.getSurfaceVariant(context)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: gelap ? 0.22 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Pita emas di tepi atas lembaran — penanda khas halaman ini,
            // senada dengan aksen emas di halaman lain.
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[emas, emas.withValues(alpha: 0.2)],
                ),
              ),
            ),
            Stack(
              children: <Widget>[
                // Hiasan samar di sudut. Tanpa ini latarnya terasa kosong,
                // tapi kepekatannya dijaga benar-benar tipis — pada latar
                // putih, sedikit saja terlalu pekat sudah terlihat seperti
                // noda cetak, bukan hiasan.
                Positioned(
                  top: -16,
                  right: -10,
                  child: IgnorePointer(
                    child: Icon(
                      Icons.mosque_rounded,
                      size: 112,
                      color: emas.withValues(alpha: gelap ? 0.06 : 0.035),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (status.isNotEmpty && status != 'disetujui')
                        _buildPenandaStatus(status),
                      _buildLabel(emas),
                      const SizedBox(height: 12),
                      Text(
                        judul,
                        style: TextStyle(
                          color: teks,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          height: 1.34,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildPenulis(penulis, tanggal, emas, teks, redup),
                      const SizedBox(height: 20),
                      _buildOrnamen(emas),
                      const SizedBox(height: 20),

                      // `SelectableText` dipakai supaya pembaca bisa memblok
                      // satu kalimat saja untuk dikutip, tanpa harus menyalin
                      // seluruh tulisan.
                      SelectableText(
                        isi.isEmpty ? 'Tidak ada isi.' : isi,
                        style: TextStyle(
                          color: teks,
                          fontSize: 16.5 * _skala,
                          height: 1.9,
                          letterSpacing: 0.1,
                        ),
                      ),

                      const SizedBox(height: 26),
                      _buildAksi(emas),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Label kecil bernama halaman, dengan aksen batang emas.
  Widget _buildLabel(Color emas) {
    return Row(
      children: <Widget>[
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: emas,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'FAWAIDH',
          style: TextStyle(
            color: emas,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildPenulis(
    String penulis,
    String tanggal,
    Color emas,
    Color teks,
    Color redup,
  ) {
    return Row(
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: emas.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(color: emas.withValues(alpha: 0.35)),
          ),
          child: Text(
            penulis.isNotEmpty ? penulis.characters.first.toUpperCase() : '?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: emas,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                penulis,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: teks,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (tanggal.isNotEmpty) ...<Widget>[
                const SizedBox(height: 1),
                Text(tanggal, style: TextStyle(color: redup, fontSize: 11.5)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Garis pemisah dengan satu titik emas di tengah — penanda "isi dimulai".
  ///
  /// Dipilih daripada garis polos karena memberi jeda yang terasa disengaja,
  /// tanpa menambah satu pun kata.
  Widget _buildOrnamen(Color emas) {
    final Color garis = AppColors.getSurfaceVariant(context);

    return Row(
      children: <Widget>[
        Expanded(child: Container(height: 1, color: garis)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: emas, shape: BoxShape.circle),
          ),
        ),
        Expanded(child: Container(height: 1, color: garis)),
      ],
    );
  }

  Widget _buildAksi(Color emas) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _salin,
        icon: Icon(Icons.copy_rounded, size: 17, color: emas),
        label: const Text('Salin tulisan ini'),
        style: OutlinedButton.styleFrom(
          foregroundColor: emas,
          side: BorderSide(color: emas.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  /// Penanda untuk tulisan yang belum tayang.
  ///
  /// Hanya muncul kalau datanya memang membawa `status` — yaitu saat dibuka
  /// dari halaman "Fawaidh Saya". Pembaca biasa tidak pernah melihat ini.
  Widget _buildPenandaStatus(String status) {
    final bool ditolak = status == 'ditolak';

    final Color latar = ditolak
        ? Theme.of(context).colorScheme.errorContainer
        : const Color(0xFFFFF3CD);
    final Color teks = ditolak
        ? Theme.of(context).colorScheme.onErrorContainer
        : const Color(0xFF7A5C00);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            ditolak ? Icons.block_rounded : Icons.visibility_off_rounded,
            size: 16,
            color: teks,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ditolak
                  ? 'Tulisan ini tidak disetujui pengurus, jadi tidak tampil di aplikasi.'
                  : 'Belum tayang — menunggu diperiksa pengurus dulu.',
              style: TextStyle(
                color: teks,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
