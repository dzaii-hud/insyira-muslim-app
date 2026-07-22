import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DetailSurahScreen extends StatefulWidget {
  final int nomorSurah;

  const DetailSurahScreen({super.key, required this.nomorSurah});

  @override
  State<DetailSurahScreen> createState() => _DetailSurahScreenState();
}

class _DetailSurahScreenState extends State<DetailSurahScreen> {
  Map<String, dynamic>? _surahData;
  bool _isLoading = true;

  // --- VARIABEL KONTROL MODE MUSHAF / TERJEMAHAN ---
  bool _isMushafMode = false; // Default: False (Mode Terjemahan)

  @override
  void initState() {
    super.initState();
    _fetchDetailSurah();
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

  // --- FUNGSI MENGUBAH ANGKA LATIN KE ANGKA ARAB ---
  String _toArabicNumber(String number) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      number = number.replaceAll(english[i], arabic[i]);
    }
    return number;
  }

  // --- FUNGSI PINDAH HALAMAN (SWIPE) ---
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
      backgroundColor: const Color(0xFFF8F9FA),

      // --- APPBAR KHUSUS ---
      appBar: AppBar(
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
          // TOMBOL GANTI MODE (MUSHAF / TERJEMAHAN)
          IconButton(
            tooltip: 'Ganti Mode Baca',
            icon: Icon(
              _isMushafMode ? Icons.view_list_rounded : Icons.menu_book_rounded,
              color: const Color(0xFF003527),
            ),
            onPressed: () {
              setState(() {
                _isMushafMode = !_isMushafMode; // Tukar mode
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF003527)),
            onPressed: () {},
          ),
        ],
      ),

      // --- WRAPPER PENDETEKSI SWIPE (BERLAKU UNTUK KEDUA MODE) ---
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          int sensitivity = 300;
          if (details.primaryVelocity! > sensitivity) {
            _goToSurah(
              widget.nomorSurah - 1,
            ); // Geser ke kanan -> Surah Sebelumnya
          } else if (details.primaryVelocity! < -sensitivity) {
            _goToSurah(
              widget.nomorSurah + 1,
            ); // Geser ke kiri -> Surah Selanjutnya
          }
        },
        child: Container(
          color: Colors
              .transparent, // Wajib agar deteksi swipe berfungsi di seluruh layar
          width: double.infinity,
          height: double.infinity,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF003527)),
                )
              : _surahData == null
              ? const Center(child: Text('Gagal memuat data.'))
              : _isMushafMode
              ? _buildMushafView() // Panggil Tampilan Mushaf
              : _buildTranslationView(), // Panggil Tampilan Terjemahan
        ),
      ),

      // Bar Navigasi Statis Bawah (Hanya Muncul di Mode Terjemahan)
      bottomNavigationBar: (!_isLoading && _surahData != null && !_isMushafMode)
          ? _buildStickyNavigationBar()
          : null,
    );
  }

  // ==========================================
  // TAMPILAN 1: MODE TERJEMAHAN
  // ==========================================
  Widget _buildTranslationView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          _buildHeaderCard(),

          if (widget.nomorSurah != 1 && widget.nomorSurah != 9)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Text(
                "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
                style: TextStyle(
                  fontSize: 28,
                  color: Color(0xFF003527),
                  fontFamily: 'Amiri',
                ),
                textAlign: TextAlign.center,
              ),
            ),

          _buildVersesList(),
          const SizedBox(height: 100), // Jarak aman untuk bottom bar
        ],
      ),
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

  Widget _buildVersesList() {
    final List<dynamic> ayatList = _surahData!['ayat'];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ayatList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final ayat = ayatList[index];
        return Container(
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
                ],
              ),
              const SizedBox(height: 20),
              Text(
                ayat['teksArab'],
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 28,
                  color: Color(0xFF191C1D),
                  fontFamily: 'Amiri',
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
  // TAMPILAN 2: MODE MUSHAF (TANPA TERJEMAHAN)
  // ==========================================
  Widget _buildMushafView() {
    String mushafText = "";
    final List<dynamic> ayatList = _surahData!['ayat'];

    for (var ayat in ayatList) {
      String arabicNumber = _toArabicNumber(ayat['nomorAyat'].toString());
      mushafText += "${ayat['teksArab']} ﴿$arabicNumber﴾ ";
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: BoxDecoration(
          color: const Color(0xFFFDFBF7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF003527).withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF003527).withOpacity(0.05),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF003527).withOpacity(0.05),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: const Color(0xFF003527).withOpacity(0.1),
                ),
              ),
              child: Text(
                "سورة ${_surahData!['nama']}",
                style: TextStyle(
                  fontSize: 22,
                  color: const Color(0xFF003527).withOpacity(0.8),
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 30),

            if (widget.nomorSurah != 1 && widget.nomorSurah != 9)
              const Padding(
                padding: EdgeInsets.only(bottom: 30),
                child: Text(
                  "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
                  style: TextStyle(
                    fontSize: 28,
                    color: Color(0xFF003527),
                    fontFamily: 'Amiri',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                mushafText.trim(),
                textAlign: TextAlign.justify,
                style: const TextStyle(
                  fontSize: 28,
                  color: Color(0xFF003527),
                  fontFamily: 'Amiri',
                  height: 2.2,
                  wordSpacing: 2.0,
                ),
              ),
            ),

            const SizedBox(height: 50),
            Divider(
              color: const Color(0xFF003527).withOpacity(0.1),
              thickness: 1,
            ),
            const SizedBox(height: 10),

            Column(
              children: [
                Text(
                  'Surah ${_surahData!['namaLatin']}',
                  style: TextStyle(
                    fontSize: 10,
                    color: const Color(0xFF003527).withOpacity(0.4),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003527).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _toArabicNumber(widget.nomorSurah.toString()),
                    style: const TextStyle(
                      color: Color(0xFF003527),
                      fontWeight: FontWeight.bold,
                    ),
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
