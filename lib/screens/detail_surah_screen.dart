import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class DetailSurahScreen extends StatefulWidget {
  final int nomorSurah;
  final int? initialAyat;

  const DetailSurahScreen({
    super.key,
    required this.nomorSurah,
    this.initialAyat,
  });

  @override
  State<DetailSurahScreen> createState() => _DetailSurahScreenState();
}

class _DetailSurahScreenState extends State<DetailSurahScreen> {
  Map<String, dynamic>? _surahData;
  bool _isLoading = true;

  // --- REMOTE CONTROL UNTUK SCROLL (MODE TERJEMAHAN) ---
  final ItemScrollController _itemScrollController = ItemScrollController();
  bool _hasScrolled = false;

  // --- VARIABEL KONTROL MODE MUSHAF / TERJEMAHAN ---
  bool _isMushafMode = false; // Default: False (Mode Terjemahan)

  // --- CONTROLLER HALAMAN MUSHAF (MODE BUKU FISIK) ---
  late PageController _pageController;
  int _currentPageIndex = 0;

  // --- [BARU] SERVICE & CACHE UNTUK MODE MUSHAF FONT QCF ---
  // TODO: Ganti dengan client_id & client_secret hasil daftar di
  // https://api-docs.quran.foundation (Request Access -> Content API).
  final QuranFoundationApi _quranApi = QuranFoundationApi(
    clientId: '3d39f639-f1eb-40ea-bc4c-0ffe73bbbcd1',
    clientSecret:
        'qfcs_1d4f0504be744cfea3366da24ab3e41c142a253be221454585541ea937d15965',
  );
  final Map<int, MushafPageData> _pageDataCache = {};

  // Database Pemetaan Halaman Awal untuk 114 Surah (Standar Mushaf Madinah)
  final List<int> _surahStartPage = [
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

  @override
  void initState() {
    super.initState();
    // Inisialisasi halaman buku agar langsung melompat ke halaman awal Surah yang dipilih
    _currentPageIndex = _surahStartPage[widget.nomorSurah - 1] - 1;
    _pageController = PageController(initialPage: _currentPageIndex);

    _fetchDetailSurah();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- FUNGSI MELUNCUR KE AYAT YANG DITANDAI (KHUSUS TERJEMAHAN) ---
  void _jumpToBookmarkedAyah() {
    if (widget.initialAyat == null) return;
    final bool hasBismillah = widget.nomorSurah != 1 && widget.nomorSurah != 9;
    final int headerCount = hasBismillah ? 2 : 1;

    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: (widget.initialAyat! - 1) + headerCount,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _fetchDetailSurah() async {
    try {
      final response = await http.get(
        Uri.parse('https://equran.id/api/v2/surat/${widget.nomorSurah}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _surahData = data['data'];
          _isLoading = false;
        });
      } else {
        throw Exception('Gagal memuat detail surah');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error: $e");
    }
  }

  // --- FUNGSI SIMPAN BOOKMARK (TERAKHIR DIBACA) ---
  Future<void> _saveBookmark(int nomorAyat) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_surah_number', widget.nomorSurah);
      await prefs.setString('last_surah_name', _surahData!['namaLatin']);
      await prefs.setInt('last_ayat', nomorAyat);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🔖 Ditandai: ${_surahData!['namaLatin']} Ayat $nomorAyat',
          ),
          backgroundColor: const Color(0xFF003527),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Gagal menandai ayat, coba lagi.'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  // --- FUNGSI PINDAH HALAMAN SURAH ---
  void _goToSurah(int nomor) {
    if (nomor >= 1 && nomor <= 114) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Memuat Surah ke-$nomor...'),
          duration: const Duration(milliseconds: 800),
          backgroundColor: const Color(0xFF003527),
        ),
      );

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) =>
              DetailSurahScreen(nomorSurah: nomor),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isMushafMode ? Colors.white : const Color(0xFFF8F9FA),

      // --- APPBAR (DISEMBUNYIKAN SAAT MODE MUSHAF) ---
      appBar: _isMushafMode
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: Color(0xFF003527),
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                _surahData != null ? _surahData!['namaLatin'] : 'Memuat...',
                style: const TextStyle(
                  color: Color(0xFF003527),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  tooltip: 'Ganti Mode Baca',
                  icon: const Icon(
                    Icons.menu_book_rounded,
                    color: Color(0xFF003527),
                  ),
                  onPressed: () {
                    setState(() {
                      _isMushafMode = true; // Tukar ke Mushaf Mode
                    });
                  },
                ),
              ],
            ),

      // --- BODY UTAMA ---
      body: SafeArea(
        child: _isMushafMode
            ? _buildMushafView() // Panggil Tampilan Mushaf Halaman (Font QCF)
            : GestureDetector(
                // SWIPE SURAH HANYA AKTIF DI MODE TERJEMAHAN
                onHorizontalDragEnd: (details) {
                  int sensitivity = 300;
                  if (details.primaryVelocity! > sensitivity) {
                    _goToSurah(widget.nomorSurah - 1);
                  } else if (details.primaryVelocity! < -sensitivity) {
                    _goToSurah(widget.nomorSurah + 1);
                  }
                },
                child: Container(
                  color: Colors.transparent,
                  width: double.infinity,
                  height: double.infinity,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF003527),
                          ),
                        )
                      : _surahData == null
                      ? const Center(child: Text('Gagal memuat data.'))
                      : _buildTranslationView(),
                ),
              ),
      ),

      // --- TOMBOL KAPSUL (LOMPAT AYAT) HANYA DI MODE TERJEMAHAN ---
      floatingActionButton: (widget.initialAyat != null && !_isMushafMode)
          ? FloatingActionButton.extended(
              onPressed: _jumpToBookmarkedAyah,
              backgroundColor: const Color(0xFF003527),
              elevation: 4,
              icon: const Icon(
                Icons.bookmark,
                color: Color(0xFF95D3BA),
                size: 18,
              ),
              label: Text(
                'Ke Ayat ${widget.initialAyat}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            )
          : null,

      // --- BAR NAVIGASI BAWAH (Hanya di mode terjemahan) ---
      bottomNavigationBar: (!_isLoading && _surahData != null && !_isMushafMode)
          ? _buildStickyNavigationBar()
          : null,
    );
  }

  // ==========================================
  // TAMPILAN 1: MODE TERJEMAHAN (TIDAK ADA YANG DIUBAH)
  // ==========================================
  Widget _buildTranslationView() {
    final List<dynamic> ayatList = _surahData!['ayat'];
    final bool hasBismillah = widget.nomorSurah != 1 && widget.nomorSurah != 9;
    final int headerCount = hasBismillah ? 2 : 1;

    if (widget.initialAyat != null && !_hasScrolled) {
      _hasScrolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_itemScrollController.isAttached) {
            _itemScrollController.scrollTo(
              index: (widget.initialAyat! - 1) + headerCount,
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOutCubic,
            );
          }
        });
      });
    }

    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: headerCount + ayatList.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _buildHeaderCard(),
          );
        }

        if (hasBismillah && index == 1) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 30),
            child: Text(
              "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
              style: TextStyle(
                fontSize: 28,
                color: Color(0xFF003527),
                fontFamily: 'LPMQ',
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        if (index == headerCount + ayatList.length) {
          return const SizedBox(height: 100);
        }

        final ayatIndex = index - headerCount;
        final ayat = ayatList[ayatIndex];

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            ayat['nomorAyat'].toString(),
                            style: const TextStyle(
                              color: Color(0xFF003527),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -4,
                        left: -4,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF904D00),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.bookmark_add_outlined,
                      color: Color(0xFF904D00),
                    ),
                    tooltip: 'Tandai Terakhir Dibaca',
                    onPressed: () => _saveBookmark(ayat['nomorAyat']),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                ayat['teksArab'],
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 28,
                  color: Color(0xFF191C1D),
                  fontFamily: 'LPMQ',
                  height: 2.0,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Color(0xFF904D00), width: 3),
                  ),
                ),
                child: Text(
                  ayat['teksIndonesia'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2B6954),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF003527).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Baca Al-Quran',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _surahData!['namaLatin'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _surahData!['arti'].toString().toUpperCase(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(
              color: Colors.white30,
              thickness: 1,
              endIndent: 40,
              indent: 40,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                _surahData!['tempatTurun'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 20),
              const Icon(Icons.menu_book, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                '${_surahData!['jumlahAyat']} Ayat',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStickyNavigationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                    color: widget.nomorSurah > 1
                        ? Colors.grey.shade400
                        : Colors.grey.shade200,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.white,
                ),
                onPressed: widget.nomorSurah > 1
                    ? () => _goToSurah(widget.nomorSurah - 1)
                    : null,
                icon: const Icon(Icons.navigate_before, size: 20),
                label: const Text(
                  'Sebelumnya',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF003527),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: widget.nomorSurah < 114
                    ? () => _goToSurah(widget.nomorSurah + 1)
                    : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Selanjutnya',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.navigate_next, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAMPILAN 2: MODE MUSHAF — [DIUPGRADE] SEKARANG PAKAI FONT QCF
  // Bukan lagi gambar network (yang sumbernya 404 / tidak valid).
  // Layout per-baris di-generate dari data resmi Quran Foundation API,
  // dirender pakai font khusus per halaman supaya hasilnya identik
  // dengan mushaf cetak (Madani Mushaf, 604 halaman).
  // ==========================================

  // Cache di memori supaya pindah halaman bolak-balik tidak fetch ulang.
  Future<MushafPageData> _loadMushafPage(int pageNumber) async {
    if (_pageDataCache.containsKey(pageNumber)) {
      return _pageDataCache[pageNumber]!;
    }
    // Font & data diambil paralel biar lebih cepat.
    final results = await Future.wait([
      QcfFontLoader.ensureLoaded(pageNumber),
      _quranApi.fetchPageWords(pageNumber),
    ]);
    final words = results[1] as List<MushafWord>;
    final pageData = MushafPageData.fromWords(pageNumber, words);
    _pageDataCache[pageNumber] = pageData;
    return pageData;
  }

  Widget _buildMushafView() {
    return Stack(
      children: [
        // 1. AREA BACA FULL SCREEN — SATU HALAMAN MUSHAF PER LAYAR, TEKS FONT QCF
        Directionality(
          textDirection: TextDirection.rtl,
          child: PageView.builder(
            controller: _pageController,
            // Krusial: reverse: true supaya geser mengikuti arah baca Arab,
            // dikombinasikan dengan Directionality.rtl di atas.
            reverse: true,
            itemCount: 604, // Total halaman Mushaf Madinah
            onPageChanged: (index) {
              setState(() {
                _currentPageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final pageNumber = index + 1;

              return Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: FutureBuilder<MushafPageData>(
                  future: _loadMushafPage(pageNumber),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF003527),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.wifi_off_rounded,
                                color: Color(0xFF904D00),
                                size: 32,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Gagal memuat halaman $pageNumber.\n${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => setState(() {
                                  _pageDataCache.remove(pageNumber);
                                }),
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final page = snapshot.data!;
                    final fontFamily =
                        'QCF_P${pageNumber.toString().padLeft(3, '0')}';

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: page.lines.map((line) {
                        return Text(
                          line.renderedText,
                          textAlign: TextAlign.justify,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 24,
                            color: const Color(0xFF191C1D),
                            height: 1.7,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              );
            },
          ),
        ),

        // 2. BOTTOM BAR NAVIGASI & INFORMASI HALAMAN (TETAP DI BAWAH, DESAIN SAMA)
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 55,
            decoration: const BoxDecoration(
              color: Color(0xFF538C61), // Hijau khas mushaf
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Kembali',
                ),

                // Indikator Halaman (Otomatis update ketika digeser)
                Text(
                  "Halaman ${_currentPageIndex + 1}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),

                IconButton(
                  icon: const Icon(
                    Icons.view_list_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () {
                    // Tombol untuk balik ke Mode Terjemahan
                    setState(() {
                      _isMushafMode = false;
                    });
                  },
                  tooltip: 'Kembali ke Terjemahan',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ==================================================================
// [BARU] KELAS PENDUKUNG MODE MUSHAF FONT QCF
// Sengaja ditaruh di file yang sama (bukan file terpisah) sesuai
// permintaan — supaya tetap satu file yang bisa langsung dipakai.
// ==================================================================

/// Satu kata dalam halaman mushaf, sesuai struktur data dari
/// Quran Foundation Content API (word_fields=code_v2,line_number,page_number).
class MushafWord {
  final int pageNumber;
  final int lineNumber;
  final String verseKey;
  final int position;
  final String codeV2; // glyph khusus untuk font QCF v2 di halaman ini

  MushafWord({
    required this.pageNumber,
    required this.lineNumber,
    required this.verseKey,
    required this.position,
    required this.codeV2,
  });

  factory MushafWord.fromJson(Map<String, dynamic> json) {
    return MushafWord(
      pageNumber: json['page_number'] as int,
      lineNumber: json['line_number'] as int,
      verseKey: json['verse_key'] as String? ?? '',
      position: json['position'] as int? ?? 0,
      codeV2: json['code_v2'] as String? ?? '',
    );
  }
}

/// Satu baris = kumpulan MushafWord dengan line_number sama, sudah terurut.
class MushafLine {
  final int lineNumber;
  final List<MushafWord> words;

  MushafLine({required this.lineNumber, required this.words});

  /// Gabungkan semua glyph kata jadi satu string supaya bisa dirender
  /// dengan SATU Text widget + TextAlign.justify (mirip mushaf cetak).
  String get renderedText => words.map((w) => w.codeV2).join();
}

/// Satu halaman penuh mushaf, dikelompokkan per baris dari daftar kata.
class MushafPageData {
  final int pageNumber;
  final List<MushafLine> lines;

  MushafPageData({required this.pageNumber, required this.lines});

  factory MushafPageData.fromWords(int pageNumber, List<MushafWord> words) {
    final Map<int, List<MushafWord>> grouped = {};
    for (final w in words) {
      grouped.putIfAbsent(w.lineNumber, () => []).add(w);
    }
    final lines = grouped.entries.map((e) {
      e.value.sort((a, b) {
        final verseCompare = a.verseKey.compareTo(b.verseKey);
        if (verseCompare != 0) return verseCompare;
        return a.position.compareTo(b.position);
      });
      return MushafLine(lineNumber: e.key, words: e.value);
    }).toList()..sort((a, b) => a.lineNumber.compareTo(b.lineNumber));

    return MushafPageData(pageNumber: pageNumber, lines: lines);
  }
}

/// Komunikasi ke Quran Foundation Content API (penerus resmi api.quran.com).
/// Dokumentasi: https://api-docs.quran.foundation
///
/// ‼️ CATATAN KEAMANAN: client_secret di sini HANYA untuk prototipe/dev.
/// Untuk rilis produksi, pindahkan proses tukar token ke backend milikmu
/// sendiri supaya client_secret tidak ikut ter-bundle di dalam APK/IPA
/// (APK bisa di-decompile dan secret bisa dibaca orang lain).
class QuranFoundationApi {
  QuranFoundationApi({required this.clientId, required this.clientSecret});

  final String clientId;
  final String clientSecret;

  // ‼️ PENTING: URL di bawah ini pakai environment PRELIVE (sandbox/testing),
  // karena Client ID & Secret yang kamu daftarkan sekarang ada di tab "Prelive"
  // dashboard Quran Foundation. Kalau nanti sudah siap rilis produksi:
  // 1. Buka tab "Production" di dashboard, generate Client ID & Secret baru
  //    (BEDA dari yang Prelive, tidak bisa dipakai silang).
  // 2. Ganti kedua URL di bawah ini ke domain production:
  //    _tokenUrl -> https://oauth2.quran.foundation/oauth2/token
  //    _apiBase  -> https://apis.quran.foundation/content/api/v4
  static const _tokenUrl =
      'https://prelive-oauth2.quran.foundation/oauth2/token';
  static const _apiBase =
      'https://apis-prelive.quran.foundation/content/api/v4';
  static const int _mushafIdQcfV2 = 1; // layout mushaf Madinah standar

  String? _cachedToken;
  DateTime? _tokenExpiry;

  Future<String> _getAccessToken() async {
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(
          _tokenExpiry!.subtract(const Duration(seconds: 30)),
        )) {
      return _cachedToken!;
    }

    final basicAuth = base64Encode(utf8.encode('$clientId:$clientSecret'));
    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: {
        'Authorization': 'Basic $basicAuth',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'grant_type': 'client_credentials', 'scope': 'content'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gagal ambil access token (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _cachedToken = data['access_token'] as String;
    final expiresIn = data['expires_in'] as int? ?? 3600;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
    return _cachedToken!;
  }

  /// Ambil semua kata di satu halaman mushaf (1-604) lengkap dengan
  /// line_number (posisi baris) dan code_v2 (glyph font QCF).
  Future<List<MushafWord>> fetchPageWords(int pageNumber) async {
    final token = await _getAccessToken();

    final uri = Uri.parse('$_apiBase/verses/by_page/$pageNumber').replace(
      queryParameters: {
        'words': 'true',
        'word_fields': 'code_v2,line_number,page_number',
        'mushaf': '$_mushafIdQcfV2',
        'per_page': '50',
      },
    );

    final response = await http.get(
      uri,
      headers: {'x-auth-token': token, 'x-client-id': clientId},
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gagal ambil halaman $pageNumber (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final verses = data['verses'] as List<dynamic>? ?? [];

    // 🔎 DEBUG SEMENTARA — hapus lagi setelah masalah ketemu.
    debugPrint(
      '[QCF-DEBUG] Halaman $pageNumber: jumlah ayat = ${verses.length}',
    );
    if (verses.isNotEmpty) {
      debugPrint(
        '[QCF-DEBUG] Contoh ayat pertama (raw): ${jsonEncode(verses.first)}',
      );
    } else {
      debugPrint(
        '[QCF-DEBUG] Response penuh (verses kosong): ${response.body}',
      );
    }

    final words = <MushafWord>[];
    for (final verse in verses) {
      final verseKey = verse['verse_key'] as String? ?? '';
      final wordList = verse['words'] as List<dynamic>? ?? [];
      for (final w in wordList) {
        final map = Map<String, dynamic>.from(w as Map);
        map['verse_key'] = map['verse_key'] ?? verseKey;
        words.add(MushafWord.fromJson(map));
      }
    }

    // 🔎 DEBUG SEMENTARA
    debugPrint('[QCF-DEBUG] Total kata ter-parse: ${words.length}');
    if (words.isNotEmpty) {
      debugPrint(
        '[QCF-DEBUG] Contoh code_v2 kata pertama: "${words.first.codeV2}"',
      );
    }

    return words;
  }
}

/// Loader font QCF per halaman, memakai dart:ui FontLoader supaya TIDAK
/// perlu mendaftarkan 604 font satu-satu di pubspec.yaml.
///
/// Syarat: file font sudah didownload & ditaruh di
/// assets/fonts/QCF/QCF2XXX.ttf (XXX = nomor halaman, 3 digit, contoh
/// QCF2001.ttf untuk halaman 1). Lihat instruksi download di penjelasan.
class QcfFontLoader {
  static final Set<int> _loadedPages = {};

  static Future<void> ensureLoaded(int pageNumber) async {
    if (_loadedPages.contains(pageNumber)) return;

    final padded = pageNumber.toString().padLeft(3, '0');
    final familyName = 'QCF_P$padded';
    final assetPath = 'assets/fonts/QCF/QCF2$padded.ttf';

    try {
      final fontData = await rootBundle.load(assetPath);
      final loader = FontLoader(familyName);
      loader.addFont(Future.value(fontData));
      await loader.load();
      _loadedPages.add(pageNumber);
    } catch (e) {
      throw Exception(
        'Font untuk halaman $pageNumber belum ada di $assetPath. '
        'Pastikan sudah didownload sesuai instruksi. ($e)',
      );
    }
  }
}
