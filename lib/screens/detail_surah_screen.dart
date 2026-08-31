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
  final QuranFoundationApi _quranApi = QuranFoundationApi(
    clientId: '97c651f5-6f20-44e6-941c-ae5c9f2296f1',
    clientSecret:
        'qfcs_a397381eee834fd7a4c23007e8b7a4a7f53c29790b3c42569d970af3c4e6cd6d',
  );
  final Map<int, MushafPageData> _pageDataCache = {};
  double _mushafFontSize = 30; // bisa diubah user lewat panel pengaturan

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

  // --- [BARU] Simpan halaman mushaf yang ditandai user ---
  Future<void> _saveMushafBookmark(int pageNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_mushaf_page', pageNumber);
      await prefs.setInt('last_surah_number', widget.nomorSurah);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔖 Halaman $pageNumber ditandai'),
          backgroundColor: const Color(0xFF003527),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Gagal menandai halaman, coba lagi.'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  // --- [BARU] Panel buat atur ukuran teks (lingkaran kecil di layar) ---
  void _showMushafFontSizeSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const Text(
                    'Ukuran Teks',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF003527),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('A', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: Slider(
                          value: _mushafFontSize,
                          min: 20,
                          max: 44,
                          activeColor: const Color(0xFF003527),
                          onChanged: (value) {
                            setSheetState(() {});
                            setState(() => _mushafFontSize = value);
                          },
                        ),
                      ),
                      const Text('A', style: TextStyle(fontSize: 28)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- [BARU] Hitung ukuran font PALING PAS buat 1 halaman, biar semua
  // baris mushaf pasti muat dalam 1 baris (tidak ke-wrap otomatis oleh
  // Flutter, yang bikin ayat keliatan "kepotong" jadi 2 baris visual).
  // Caranya: ukur lebar baris TERPANJANG di halaman itu pada ukuran font
  // yang diinginkan user, lalu skalakan turun kalau kepanjangan.
  double _computeFitFontSize({
    required List<String> lineTexts,
    required String fontFamily,
    required double maxWidth,
    required double desiredFontSize,
  }) {
    if (lineTexts.isEmpty || maxWidth <= 0) return desiredFontSize;

    double widest = 0;
    for (final text in lineTexts) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontFamily: fontFamily, fontSize: desiredFontSize),
        ),
        textDirection: TextDirection.rtl,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
    }

    if (widest <= maxWidth || widest == 0) return desiredFontSize;

    final scale = (maxWidth / widest) * 0.98; // sedikit margin aman
    return (desiredFontSize * scale).clamp(12.0, desiredFontSize);
  }

  // --- [BARU] Render satu item halaman: bisa berupa header nama surah,
  // basmalah dekoratif, atau baris ayat sungguhan (font QCF).
  Widget _buildMushafItem(
    MushafPageItem item,
    String fontFamily,
    double fittedFontSize,
  ) {
    if (item is SurahHeaderItem) {
      final name = (item.chapterNumber >= 1 && item.chapterNumber <= 114)
          ? kSurahArabicNames[item.chapterNumber - 1]
          : '';
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF003527).withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF003527).withOpacity(0.15)),
        ),
        child: Text(
          'سورة $name',
          style: const TextStyle(
            fontFamily: 'LPMQ',
            fontSize: 20,
            color: Color(0xFF003527),
          ),
        ),
      );
    }

    if (item is BasmalahItem) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'LPMQ',
            fontSize: 24,
            color: Color(0xFF003527),
          ),
        ),
      );
    }

    final line = (item as MushafLineItem).line;
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          line.renderedText,
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: fittedFontSize,
            color: const Color(0xFF191C1D),
            height: 1.7,
          ),
        ),
      ),
    );
  }

  Widget _buildPageNumberPill(int pageNumber) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF003527).withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF003527).withOpacity(0.1)),
        ),
        child: Text(
          'Halaman $pageNumber',
          style: const TextStyle(
            color: Color(0xFF003527),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildMushafView() {
    return Stack(
      children: [
        // 1. AREA BACA — SATU HALAMAN MUSHAF PER LAYAR, TEKS FONT QCF,
        //    dibungkus tampilan kartu ala mushaf (border tipis + shadow lembut)
        Directionality(
          textDirection: TextDirection.rtl,
          child: PageView.builder(
            controller: _pageController,
            reverse: true,
            itemCount: 604,
            onPageChanged: (index) {
              setState(() {
                _currentPageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final pageNumber = index + 1;

              return Container(
                margin: const EdgeInsets.fromLTRB(16, 72, 16, 84),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFBF7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF003527).withOpacity(0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF003527).withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
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
                    final lineTextsOnly = page.items
                        .whereType<MushafLineItem>()
                        .map((e) => e.line.renderedText)
                        .toList();

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final fittedFontSize = _computeFitFontSize(
                          lineTexts: lineTextsOnly,
                          fontFamily: fontFamily,
                          maxWidth: constraints.maxWidth,
                          desiredFontSize: _mushafFontSize,
                        );

                        return Column(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: page.items
                                    .map(
                                      (item) => _buildMushafItem(
                                        item,
                                        fontFamily,
                                        fittedFontSize,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildPageNumberPill(pageNumber),
                          ],
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),

        // 2. TOP BAR — menu balik ke mode terjemahan + tombol tandai halaman
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.96),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Color(0xFF003527),
                      size: 18,
                    ),
                    tooltip: 'Kembali ke Mode Terjemahan',
                    onPressed: () {
                      setState(() {
                        _isMushafMode = false;
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      _surahData != null ? _surahData!['namaLatin'] : '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF003527),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.bookmark_add_outlined,
                      color: Color(0xFF904D00),
                    ),
                    tooltip: 'Tandai Halaman Ini',
                    onPressed: () => _saveMushafBookmark(_currentPageIndex + 1),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 3. FAB BULAT KECIL — atur ukuran teks (ramah untuk lansia)
        Positioned(
          right: 16,
          bottom: 92,
          child: FloatingActionButton(
            heroTag: 'mushaf_font_size_fab',
            mini: true,
            backgroundColor: const Color(0xFF003527),
            onPressed: _showMushafFontSizeSheet,
            child: const Icon(Icons.text_fields, color: Colors.white, size: 20),
          ),
        ),

        // 4. BOTTOM BAR — navigasi halaman sebelumnya/selanjutnya
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 64,
            decoration: const BoxDecoration(color: Color(0xFF538C61)),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 26,
                    ),
                    tooltip: 'Halaman Sebelumnya',
                    onPressed: _currentPageIndex > 0
                        ? () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          )
                        : null,
                  ),
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
                      Icons.chevron_right,
                      color: Colors.white,
                      size: 26,
                    ),
                    tooltip: 'Halaman Selanjutnya',
                    onPressed: _currentPageIndex < 603
                        ? () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          )
                        : null,
                  ),
                ],
              ),
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

  /// Nomor surah dari verse_key (format "surah:ayat"), contoh "67:1" -> 67.
  int get chapterNumber {
    final parts = verseKey.split(':');
    return parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
  }

  /// Nomor ayat dari verse_key, contoh "67:1" -> 1.
  int get ayahNumber {
    final parts = verseKey.split(':');
    return parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
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

/// Item yang dirender di halaman mushaf — bisa baris ayat sungguhan,
/// header nama surah, atau basmalah dekoratif (muncul otomatis kalau
/// halaman ini memuat awal sebuah surah baru).
abstract class MushafPageItem {}

class MushafLineItem extends MushafPageItem {
  final MushafLine line;
  MushafLineItem(this.line);
}

class SurahHeaderItem extends MushafPageItem {
  final int chapterNumber;
  SurahHeaderItem(this.chapterNumber);
}

class BasmalahItem extends MushafPageItem {}

/// Satu halaman penuh mushaf, dikelompokkan per baris dari daftar kata,
/// plus disisipi header nama surah + basmalah otomatis kalau ada surah
/// baru yang mulai di halaman ini.
class MushafPageData {
  final int pageNumber;
  final List<MushafPageItem> items;

  MushafPageData({required this.pageNumber, required this.items});

  factory MushafPageData.fromWords(int pageNumber, List<MushafWord> words) {
    final Map<int, List<MushafWord>> grouped = {};
    for (final w in words) {
      grouped.putIfAbsent(w.lineNumber, () => []).add(w);
    }
    final lines = grouped.entries.map((e) {
      e.value.sort((a, b) {
        if (a.chapterNumber != b.chapterNumber) {
          return a.chapterNumber.compareTo(b.chapterNumber);
        }
        if (a.ayahNumber != b.ayahNumber) {
          return a.ayahNumber.compareTo(b.ayahNumber);
        }
        return a.position.compareTo(b.position);
      });
      return MushafLine(lineNumber: e.key, words: e.value);
    }).toList()..sort((a, b) => a.lineNumber.compareTo(b.lineNumber));

    // Sisipkan header nama surah + basmalah SEBELUM baris yang memuat
    // kata pertama (position == 1) dari ayat pertama (ayahNumber == 1)
    // sebuah surah. Al-Fatihah (basmalah-nya sudah jadi ayat 1) dan
    // At-Taubah (memang tidak pakai basmalah) dikecualikan dari basmalah,
    // tapi tetap dapat header nama surah.
    final items = <MushafPageItem>[];
    for (final line in lines) {
      final surahStartWord = line.words.firstWhere(
        (w) => w.ayahNumber == 1 && w.position == 1,
        orElse: () => MushafWord(
          pageNumber: pageNumber,
          lineNumber: -1,
          verseKey: '',
          position: -1,
          codeV2: '',
        ),
      );

      if (surahStartWord.lineNumber != -1) {
        final chapter = surahStartWord.chapterNumber;
        items.add(SurahHeaderItem(chapter));
        if (chapter != 1 && chapter != 9) {
          items.add(BasmalahItem());
        }
      }

      items.add(MushafLineItem(line));
    }

    return MushafPageData(pageNumber: pageNumber, items: items);
  }
}

/// Daftar nama 114 surah dalam huruf Arab, dipakai untuk header dekoratif
/// yang muncul otomatis di awal setiap surah pada mode mushaf.
const List<String> kSurahArabicNames = [
  'الفاتحة',
  'البقرة',
  'آل عمران',
  'النساء',
  'المائدة',
  'الأنعام',
  'الأعراف',
  'الأنفال',
  'التوبة',
  'يونس',
  'هود',
  'يوسف',
  'الرعد',
  'إبراهيم',
  'الحجر',
  'النحل',
  'الإسراء',
  'الكهف',
  'مريم',
  'طه',
  'الأنبياء',
  'الحج',
  'المؤمنون',
  'النور',
  'الفرقان',
  'الشعراء',
  'النمل',
  'القصص',
  'العنكبوت',
  'الروم',
  'لقمان',
  'السجدة',
  'الأحزاب',
  'سبأ',
  'فاطر',
  'يس',
  'الصافات',
  'ص',
  'الزمر',
  'غافر',
  'فصلت',
  'الشورى',
  'الزخرف',
  'الدخان',
  'الجاثية',
  'الأحقاف',
  'محمد',
  'الفتح',
  'الحجرات',
  'ق',
  'الذاريات',
  'الطور',
  'النجم',
  'القمر',
  'الرحمن',
  'الواقعة',
  'الحديد',
  'المجادلة',
  'الحشر',
  'الممتحنة',
  'الصف',
  'الجمعة',
  'المنافقون',
  'التغابن',
  'الطلاق',
  'التحريم',
  'الملك',
  'القلم',
  'الحاقة',
  'المعارج',
  'نوح',
  'الجن',
  'المزمل',
  'المدثر',
  'القيامة',
  'الإنسان',
  'المرسلات',
  'النبأ',
  'النازعات',
  'عبس',
  'التكوير',
  'الانفطار',
  'المطففين',
  'الانشقاق',
  'البروج',
  'الطارق',
  'الأعلى',
  'الغاشية',
  'الفجر',
  'البلد',
  'الشمس',
  'الليل',
  'الضحى',
  'الشرح',
  'التين',
  'العلق',
  'القدر',
  'البينة',
  'الزلزلة',
  'العاديات',
  'القارعة',
  'التكاثر',
  'العصر',
  'الهمزة',
  'الفيل',
  'قريش',
  'الماعون',
  'الكوثر',
  'الكافرون',
  'النصر',
  'المسد',
  'الإخلاص',
  'الفلق',
  'الناس',
];

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

  static const _tokenUrl = 'https://oauth2.quran.foundation/oauth2/token';
  static const _apiBase = 'https://apis.quran.foundation/content/api/v4';
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
