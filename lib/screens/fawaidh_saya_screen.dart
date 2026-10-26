import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../router/app_router.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_content.dart';

/// Halaman khusus akun yang **terdaftar sebagai ustadz**: mengisi dan
/// mengelola fawaidh miliknya sendiri.
///
/// Dua hal yang sengaja dibuat begini:
///
/// 1. **Tulisan baru tidak langsung tayang.** Semuanya masuk sebagai
///    "Menunggu" sampai admin menyetujuinya. Karena itu setiap tulisan diberi
///    lencana status — supaya ustadz tahu mana yang sudah tayang dan mana yang
///    masih menunggu, bukan menebak-nebak.
///
/// 2. **Yang bisa disentuh hanya tulisannya sendiri.** Penyaringan dilakukan
///    di server (lewat pemilik akun), bukan di aplikasi. Jadi walaupun id
///    tulisan orang lain dikirim, server tetap menolak.
///
/// Foto profil sengaja belum bisa diunggah dari sini — panel admin yang
/// mengurusnya. Menambahkan pemilih gambar butuh paket baru, dan itu lebih
/// baik ditambahkan setelah alurnya dipakai dulu.
class FawaidhSayaScreen extends StatefulWidget {
  const FawaidhSayaScreen({super.key});

  @override
  State<FawaidhSayaScreen> createState() => _FawaidhSayaScreenState();
}

class _FawaidhSayaScreenState extends State<FawaidhSayaScreen> {
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _daftar = <Map<String, dynamic>>[];
  bool _memuat = true;
  String _galat = '';

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    if (mounted) {
      setState(() {
        _memuat = true;
        _galat = '';
      });
    }

    try {
      final Map<String, String> header = await _authService.authHeaders();
      final http.Response jawaban = await http
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/fawaidh/saya'),
            headers: header,
          )
          .timeout(AppConfig.requestTimeout);

      if (!mounted) return;

      if (jawaban.statusCode == 200) {
        final List<dynamic> data = json.decode(jawaban.body) as List<dynamic>;
        setState(() {
          _daftar = data
              .map((e) => (e as Map).cast<String, dynamic>())
              .toList();
          _memuat = false;
        });
        return;
      }

      setState(() {
        _memuat = false;
        _galat = jawaban.statusCode == 403
            ? 'Akunmu belum terdaftar sebagai ustadz. Hubungi pengurus untuk '
                  'didaftarkan.'
            : 'Gagal memuat tulisanmu (${jawaban.statusCode}).';
      });
    } catch (e) {
      debugPrint('Gagal memuat fawaidh saya: $e');
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _galat = 'Tidak bisa menghubungi server. Periksa koneksimu ya.';
      });
    }
  }

  /// Membuka formulir untuk menulis fawaidh baru, atau mengubah yang sudah ada.
  Future<void> _bukaFormulir({Map<String, dynamic>? tulisan}) async {
    final bool? tersimpan = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => _FormFawaidh(tulisan: tulisan),
    );

    if (tersimpan == true) {
      await _muat();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tersimpan. Tulisanmu menunggu diperiksa pengurus dulu ya.',
          ),
        ),
      );
    }
  }

  /// Membuka halaman baca untuk tulisan ini.
  ///
  /// Datanya dititipkan lewat `extra` supaya halaman baca langsung tampil —
  /// termasuk untuk tulisan yang masih menunggu, yang memang tidak bisa
  /// diambil dari server oleh pembaca umum.
  void _baca(Map<String, dynamic> tulisan) {
    final Object? id = tulisan['id'];
    if (id == null) return;

    context.push(AppRoutes.bacaFawaidh(id), extra: tulisan);
  }

  /// Menghapus tulisan milik sendiri, dengan konfirmasi lebih dulu.
  Future<void> _hapus(Map<String, dynamic> tulisan) async {
    final bool setuju =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Hapus tulisan ini?'),
            content: Text(
              'Tulisan "${tulisan['judul'] ?? ''}" akan dihapus permanen dan '
              'tidak bisa dikembalikan.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Hapus'),
              ),
            ],
          ),
        ) ??
        false;

    if (!setuju) return;

    try {
      final Map<String, String> header = await _authService.authHeaders();
      final http.Response jawaban = await http
          .delete(
            Uri.parse('${AppConfig.apiBaseUrl}/fawaidh/saya/${tulisan['id']}'),
            headers: header,
          )
          .timeout(AppConfig.requestTimeout);

      if (!mounted) return;

      if (jawaban.statusCode == 200) {
        await _muat();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus (${jawaban.statusCode}).')),
      );
    } catch (e) {
      debugPrint('Gagal menghapus fawaidh: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa menghubungi server.')),
      );
    }
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
        title: const Text(
          'Fawaidh Saya',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _bukaFormulir(),
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Tulis Fawaidh'),
      ),
      body: SafeArea(top: false, child: ResponsiveContent(child: _buildIsi())),
    );
  }

  Widget _buildIsi() {
    if (_memuat) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_galat.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.info_outline_rounded,
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

    if (_daftar.isEmpty) {
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
                'Kamu belum menulis fawaidh.\nTekan "Tulis Fawaidh" untuk '
                'memulai.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.getOnSurfaceVariant(context),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 96),
      itemCount: _daftar.length,
      itemBuilder: (BuildContext context, int i) => _buildKartu(_daftar[i]),
    );
  }

  Widget _buildKartu(Map<String, dynamic> tulisan) {
    final String status = (tulisan['status'] ?? '').toString();
    final String isi = (tulisan['isi'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: AppColors.getSurfaceContainerLow(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.getSurfaceVariant(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      (tulisan['judul'] ?? '').toString(),
                      style: TextStyle(
                        color: AppColors.getTextPrimary(context),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _lencanaStatus(status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                isi,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.getOnSurfaceVariant(context),
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              // Memakai Wrap, bukan Row: tiga tombol berjajar bisa terpotong di
              // layar sempit. Wrap membiarkannya turun baris kalau tidak muat.
              Wrap(
                children: <Widget>[
                  TextButton.icon(
                    onPressed: () => _baca(tulisan),
                    icon: const Icon(Icons.menu_book_rounded, size: 17),
                    label: const Text('Baca'),
                  ),
                  TextButton.icon(
                    onPressed: () => _bukaFormulir(tulisan: tulisan),
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('Ubah'),
                  ),
                  TextButton.icon(
                    onPressed: () => _hapus(tulisan),
                    icon: const Icon(Icons.delete_outline_rounded, size: 17),
                    label: const Text('Hapus'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Lencana status tulisan.
  ///
  /// Ini yang menjawab pertanyaan "punyaku sudah tayang belum?" tanpa harus
  /// membuka apa pun.
  Widget _lencanaStatus(String status) {
    late final Color latar;
    late final Color teks;
    late final String label;

    switch (status) {
      case 'disetujui':
        latar = AppColors.getSurfaceVariant(context);
        teks = AppColors.getPrimaryText(context);
        label = 'Tayang';
      case 'ditolak':
        latar = Theme.of(context).colorScheme.errorContainer;
        teks = Theme.of(context).colorScheme.onErrorContainer;
        label = 'Ditolak';
      default:
        latar = const Color(0xFFFFF3CD);
        teks = const Color(0xFF7A5C00);
        label = 'Menunggu';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: teks,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Formulir menulis / mengubah fawaidh.
///
/// Dipisah jadi widget sendiri supaya teks yang sedang diketik TIDAK ikut
/// hilang setiap kali halaman di belakangnya diperbarui.
class _FormFawaidh extends StatefulWidget {
  const _FormFawaidh({this.tulisan});

  /// Tulisan yang sedang diubah. `null` berarti menulis baru.
  final Map<String, dynamic>? tulisan;

  @override
  State<_FormFawaidh> createState() => _FormFawaidhState();
}

class _FormFawaidhState extends State<_FormFawaidh> {
  late final TextEditingController _judul;
  late final TextEditingController _isi;

  bool _menyimpan = false;
  String _galat = '';

  @override
  void initState() {
    super.initState();
    _judul = TextEditingController(
      text: (widget.tulisan?['judul'] ?? '').toString(),
    );
    _isi = TextEditingController(
      text: (widget.tulisan?['isi'] ?? '').toString(),
    );
  }

  @override
  void dispose() {
    _judul.dispose();
    _isi.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final String judul = _judul.text.trim();
    final String isi = _isi.text.trim();

    if (judul.isEmpty || isi.isEmpty) {
      setState(() => _galat = 'Judul dan isinya belum diisi.');
      return;
    }

    setState(() {
      _menyimpan = true;
      _galat = '';
    });

    try {
      final AuthService auth = AuthService();

      // `authHeaders()` membawa `Content-Type: application/json`, padahal di
      // sini yang dikirim adalah isian formulir. Jenis isinya ditulis ulang
      // supaya jelas dan tidak bergantung pada perilaku bawaan paket http
      // ketika menerima Map.
      final Map<String, String> header = <String, String>{
        ...await auth.authHeaders(),
        'Content-Type': 'application/x-www-form-urlencoded',
      };

      final bool mengubah = widget.tulisan != null;
      final Uri alamat = Uri.parse(
        mengubah
            ? '${AppConfig.apiBaseUrl}/fawaidh/saya/${widget.tulisan!['id']}'
            : '${AppConfig.apiBaseUrl}/fawaidh/saya',
      );

      final Map<String, String> isian = <String, String>{
        'judul': judul,
        'isi': isi,
      };

      final http.Response jawaban = mengubah
          ? await http
                .put(alamat, headers: header, body: isian)
                .timeout(AppConfig.requestTimeout)
          : await http
                .post(alamat, headers: header, body: isian)
                .timeout(AppConfig.requestTimeout);

      if (!mounted) return;

      if (jawaban.statusCode == 200 || jawaban.statusCode == 201) {
        Navigator.pop(context, true);
        return;
      }

      setState(() {
        _menyimpan = false;
        _galat = jawaban.statusCode == 403
            ? 'Akunmu belum terdaftar sebagai ustadz.'
            : 'Gagal menyimpan (${jawaban.statusCode}). Coba lagi ya.';
      });
    } catch (e) {
      debugPrint('Gagal menyimpan fawaidh: $e');
      if (!mounted) return;
      setState(() {
        _menyimpan = false;
        _galat = 'Tidak bisa menghubungi server. Periksa koneksimu ya.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // `viewInsets` dipakai supaya formulirnya naik saat papan ketik muncul —
      // tanpa ini, kolom isi tertutup papan ketik di HP.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              widget.tulisan == null ? 'Tulis Fawaidh' : 'Ubah Fawaidh',
              style: TextStyle(
                color: AppColors.getTextPrimary(context),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tulisanmu akan diperiksa pengurus dulu sebelum tayang.',
              style: TextStyle(
                color: AppColors.getOnSurfaceVariant(context),
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _judul,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Judul',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _isi,
              minLines: 6,
              maxLines: 12,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'Isi fawaidh',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (_galat.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _galat,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _menyimpan ? null : () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _menyimpan ? null : _simpan,
                    child: _menyimpan
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Simpan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
