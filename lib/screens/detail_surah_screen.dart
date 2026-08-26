import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
            ? _buildMushafView() // Panggil Tampilan Mushaf Halaman (Images)
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
  // TAMPILAN 2: MODE MUSHAF (MENGGUNAKAN PAGEVIEW 604 HALAMAN BUKU FISIK)
  // ==========================================
  Widget _buildMushafView() {
    return Stack(
      children: [
        // 1. AREA BACA FULL SCREEN MENGGUNAKAN IMAGE MUSHAF ASLI
        PageView.builder(
          controller: _pageController,
          // Ini sangat krusial! reverse: true membuat aplikasi bisa digeser dari
          // kanan ke kiri sesuai standar membaca bahasa Arab.
          reverse: true,
          itemCount: 604, // Total halaman Al-Quran Mushaf Madinah
          onPageChanged: (index) {
            setState(() {
              _currentPageIndex = index;
            });
          },
          itemBuilder: (context, index) {
            // Standar nama file adalah page001.png sampai page604.png
            String pageStr = (index + 1).toString().padLeft(3, '0');
            // Menarik gambar resolusi HD langsung dari server open-source Global (Sangat stabil)
            String url =
                'https://raw.githubusercontent.com/quran/quran.com-images/master/width_1024/page$pageStr.png';

            return Container(
              color: Colors.white,
              // InteractiveViewer = Memungkinkan user melakukan Pinch-to-Zoom pada halaman
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 3.5, // Maksimal Zoom In
                child: Image.network(
                  url,
                  fit: BoxFit
                      .contain, // Menyesuaikan gambar agar pas dari ujung ke ujung HP
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        color: const Color(0xFF003527),
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  (loadingProgress.expectedTotalBytes ?? 1)
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Text(
                        'Gagal memuat gambar halaman.',
                        style: TextStyle(color: Colors.red),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),

        // 2. BOTTOM BAR NAVIGASI & INFORMASI HALAMAN (TETAP DI BAWAH)
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
