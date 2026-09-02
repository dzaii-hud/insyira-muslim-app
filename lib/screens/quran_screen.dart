import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

// Memanggil halaman detail surah
import 'detail_surah_screen.dart';

// --- [BARU] Pemetaan halaman awal 114 Surah (Standar Mushaf Madinah) ---
// Dipakai buat nentuin surah mana yang "punya" suatu nomor halaman, supaya
// pas user search nomor halaman langsung, kita tau surah yang benar buat
// dikirim ke DetailSurahScreen (biar mode terjemahan tetap akurat kalau
// user balik dari mode mushaf).
const List<int> kSurahStartPage = [
  1,
  2,
  50,
  77,
  106,
  128,
  151,
  177,
  187,
  208,
  221,
  235,
  249,
  255,
  262,
  267,
  282,
  293,
  305,
  312,
  322,
  332,
  342,
  350,
  359,
  367,
  377,
  385,
  396,
  404,
  411,
  415,
  418,
  428,
  434,
  440,
  446,
  453,
  458,
  467,
  477,
  483,
  489,
  496,
  499,
  502,
  507,
  511,
  515,
  518,
  520,
  523,
  526,
  528,
  531,
  534,
  537,
  542,
  545,
  549,
  551,
  553,
  554,
  556,
  558,
  560,
  562,
  564,
  566,
  568,
  570,
  572,
  574,
  575,
  577,
  578,
  580,
  582,
  583,
  585,
  586,
  587,
  587,
  589,
  590,
  591,
  591,
  592,
  593,
  594,
  595,
  595,
  596,
  596,
  597,
  597,
  598,
  598,
  599,
  599,
  600,
  600,
  601,
  601,
  601,
  602,
  602,
  602,
  603,
  603,
  603,
  604,
  604,
  604,
];

int _surahNumberForPage(int page) {
  int result = 1;
  for (int i = 0; i < kSurahStartPage.length; i++) {
    if (kSurahStartPage[i] <= page) {
      result = i + 1;
    } else {
      break;
    }
  }
  return result;
}

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  List<dynamic> _surahList = [];
  List<dynamic> _filteredSurahList = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // --- [BARU] Hasil "quick action" dari pencarian pintar (surat/halaman/
  // surat+ayat) — tampil sebagai kartu di atas daftar surah biasa.
  List<_QuickAction> _quickActions = [];

  // --- VARIABEL UNTUK MENAMPUNG DATA TERAKHIR DIBACA ---
  String? lastReadSurah;
  int? lastReadSurahNumber;
  int? lastReadAyat;
  // --- [BARU] Mode & halaman terakhir dibaca ---
  String? lastReadMode; // 'mushaf' atau 'translation'
  int? lastReadMushafPage;

  @override
  void initState() {
    super.initState();
    _fetchSurahData();
    _loadLastRead(); // Panggil fungsi memori saat layar dibuka
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- FUNGSI MENGAMBIL DATA DARI API ---
  Future<void> _fetchSurahData() async {
    try {
      final response = await http.get(
        Uri.parse('https://equran.id/api/v2/surat'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _surahList = data['data'];
          _filteredSurahList = _surahList;
          _isLoading = false;
        });
      } else {
        throw Exception('Gagal memuat data');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error mengambil data Al-Quran: $e");
    }
  }

  // --- FUNGSI MENARIK DATA BOOKMARK DARI MEMORI HP ---
  Future<void> _loadLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('last_read_mode');
    final surahNum = prefs.getInt('last_surah_number');
    final surahName = prefs.getString('last_surah_name');
    final ayat = prefs.getInt('last_ayat');
    final mushafPage = prefs.getInt('last_mushaf_page');

    // 🔎 DEBUG SEMENTARA
    debugPrint(
      '[BOOKMARK-DEBUG] LOAD -> mode=$mode surah=$surahNum name=$surahName '
      'ayat=$ayat page=$mushafPage',
    );

    setState(() {
      lastReadMode = mode;
      lastReadSurahNumber = surahNum;
      lastReadSurah = surahName;
      lastReadAyat = ayat;
      lastReadMushafPage = mushafPage;
    });
  }

  // --- FUNGSI PENCARIAN SURAH (sekarang juga bisa deteksi halaman & ayat) ---
  void _filterSurah(String query) {
    final trimmed = query.trim();
    setState(() {
      _quickActions = _buildQuickActions(trimmed);

      if (trimmed.isEmpty) {
        _filteredSurahList = _surahList;
      } else {
        _filteredSurahList = _surahList.where((surah) {
          final namaSurah = surah['namaLatin'].toString().toLowerCase();
          final artiSurah = surah['arti'].toString().toLowerCase();
          return namaSurah.contains(trimmed.toLowerCase()) ||
              artiSurah.contains(trimmed.toLowerCase());
        }).toList();
      }
    });
  }

  // --- [BARU] Deteksi pola pencarian pintar: nomor halaman, nomor surat,
  // atau "nama surat + ayat" (misal "Ali Imran 50").
  List<_QuickAction> _buildQuickActions(String query) {
    if (query.isEmpty || _surahList.isEmpty) return [];
    final actions = <_QuickAction>[];

    // Pola "<nama surat> <angka>" -> lompat langsung ke ayat tertentu.
    final surahAyatMatch = RegExp(
      r'^(.*[A-Za-z].*?)\s+(\d{1,3})$',
    ).firstMatch(query);
    if (surahAyatMatch != null) {
      final namePart = surahAyatMatch.group(1)!.trim().toLowerCase();
      final ayatNum = int.tryParse(surahAyatMatch.group(2)!);
      dynamic match;
      for (final s in _surahList) {
        if (s['namaLatin'].toString().toLowerCase().contains(namePart)) {
          match = s;
          break;
        }
      }
      if (match != null && ayatNum != null) {
        final totalAyat = match['jumlahAyat'] as int;
        if (ayatNum >= 1 && ayatNum <= totalAyat) {
          actions.add(
            _QuickAction(
              icon: Icons.menu_book_outlined,
              label: '${match['namaLatin']} • Ayat $ayatNum',
              subtitle: 'Buka di mode terjemahan',
              onTap: (context) => _openSurah(
                context,
                nomorSurah: match['nomor'],
                initialAyat: ayatNum,
              ),
            ),
          );
        }
      }
    }

    // Pola angka murni -> bisa nomor surat DAN/ATAU nomor halaman.
    if (RegExp(r'^\d+$').hasMatch(query)) {
      final n = int.parse(query);

      if (n >= 1 && n <= 114) {
        dynamic surahMatch;
        for (final s in _surahList) {
          if (s['nomor'] == n) {
            surahMatch = s;
            break;
          }
        }
        if (surahMatch != null) {
          actions.add(
            _QuickAction(
              icon: Icons.book_outlined,
              label: 'Surah ${surahMatch['namaLatin']}',
              subtitle: 'Buka Surat nomor $n',
              onTap: (context) =>
                  _openSurah(context, nomorSurah: n, initialAyat: null),
            ),
          );
        }
      }

      if (n >= 1 && n <= 604) {
        actions.add(
          _QuickAction(
            icon: Icons.menu_book_rounded,
            label: 'Halaman $n',
            subtitle: 'Buka di mode mushaf',
            onTap: (context) => _openSurah(
              context,
              nomorSurah: _surahNumberForPage(n),
              initialMode: 'mushaf',
              initialMushafPage: n,
            ),
          ),
        );
      }
    }

    return actions;
  }

  void _openSurah(
    BuildContext context, {
    required int nomorSurah,
    int? initialAyat,
    String? initialMode,
    int? initialMushafPage,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailSurahScreen(
          nomorSurah: nomorSurah,
          initialAyat: initialAyat,
          initialMode: initialMode,
          initialMushafPage: initialMushafPage,
        ),
      ),
    ).then((_) => _loadLastRead());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          _buildSearchBar(),
          if (_quickActions.isNotEmpty) _buildQuickActionsList(),
          _buildLastRead(), // Kotak hijau akan otomatis pakai data asli
          _buildListHeader(),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF003527)),
                  )
                : _filteredSurahList.isEmpty
                ? const Center(child: Text('Surah tidak ditemukan.'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: _filteredSurahList.length,
                    itemBuilder: (context, index) {
                      final surah = _filteredSurahList[index];
                      return _buildSurahItem(surah);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET KOMPONEN ---

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _filterSurah,
          decoration: InputDecoration(
            hintText: 'Cari Surah, Halaman, atau "Ali Imran 50"...',
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF707974)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  // --- [BARU] Daftar kartu hasil pencarian pintar (halaman/surat/surat+ayat) ---
  Widget _buildQuickActionsList() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: _quickActions.map((action) {
          return InkWell(
            onTap: () => action.onTap(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF003527).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF003527).withOpacity(0.12),
                ),
              ),
              child: Row(
                children: [
                  Icon(action.icon, color: const Color(0xFF003527), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF003527),
                          ),
                        ),
                        Text(
                          action.subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF904D00),
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLastRead() {
    final bool isMushaf = lastReadMode == 'mushaf';
    final bool hasBookmark =
        lastReadSurahNumber != null &&
        (isMushaf ? lastReadMushafPage != null : lastReadAyat != null);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF003527),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF064E3B).withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      'TERAKHIR DIBACA',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                if (hasBookmark) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isMushaf ? 'MODE MUSHAF' : 'MODE TERJEMAHAN',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // --- MENAMPILKAN NAMA SURAH / HALAMAN DINAMIS ---
                Text(
                  isMushaf && hasBookmark
                      ? 'Halaman $lastReadMushafPage'
                      : (lastReadSurah ?? 'Belum ada'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),

                // --- SUBJUDUL: kalau mushaf tampilkan nama surah, kalau
                // terjemahan tampilkan nomor ayat ---
                Text(
                  !hasBookmark
                      ? 'Tandai saat membaca'
                      : (isMushaf
                            ? (lastReadSurah ?? '')
                            : 'Ayat $lastReadAyat'),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),

          // --- TOMBOL LANJUTKAN ---
          InkWell(
            onTap: () {
              if (hasBookmark) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailSurahScreen(
                      nomorSurah: lastReadSurahNumber!,
                      initialAyat: isMushaf ? null : lastReadAyat,
                      initialMode: isMushaf ? 'mushaf' : null,
                      initialMushafPage: isMushaf ? lastReadMushafPage : null,
                    ),
                  ),
                ).then((_) => _loadLastRead()); // Auto-refresh saat kembali
              } else {
                // SnackBar untuk "Belum ada ayat yang ditandai"
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Belum ada ayat yang ditandai 🔖',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: const Color(0xFF904D00),
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.only(
                      bottom: MediaQuery.of(context).size.height - 200,
                      left: 20,
                      right: 20,
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: const [
                  Text(
                    'Lanjutkan',
                    style: TextStyle(
                      color: Color(0xFF904D00),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: Color(0xFF904D00), size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(
        'Daftar Surah',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF003527),
        ),
      ),
    );
  }

  Widget _buildSurahItem(dynamic surah) {
    return InkWell(
      onTap: () => _openSurah(context, nomorSurah: surah['nomor']),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.black12, width: 0.5)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: pi / 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF003527).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  Text(
                    surah['nomor'].toString(),
                    style: const TextStyle(
                      color: Color(0xFF003527),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    surah['namaLatin'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF191C1D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${surah['arti']} • ${surah['jumlahAyat']} AYAT"
                        .toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              surah['nama'],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF003527),
                fontFamily: 'LPMQ', // Font sudah kuubah ke LPMQ biar rapi!
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Model kecil buat kartu hasil pencarian pintar (halaman/surat/surat+ayat).
class _QuickAction {
  final IconData icon;
  final String label;
  final String subtitle;
  final void Function(BuildContext context) onTap;

  _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
}
