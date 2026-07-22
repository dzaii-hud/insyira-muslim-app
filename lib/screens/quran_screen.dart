import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

// Memanggil halaman detail surah
import 'detail_surah_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchSurahData();
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

  // --- FUNGSI PENCARIAN SURAH ---
  void _filterSurah(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSurahList = _surahList;
      } else {
        _filteredSurahList = _surahList.where((surah) {
          final namaSurah = surah['namaLatin'].toString().toLowerCase();
          final artiSurah = surah['arti'].toString().toLowerCase();
          return namaSurah.contains(query.toLowerCase()) ||
              artiSurah.contains(query.toLowerCase());
        }).toList();
      }
    });
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
          _buildLastRead(),
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
            hintText: 'Cari Surah atau Ayat...',
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF707974)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildLastRead() {
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.history, color: Colors.white70, size: 16),
                  SizedBox(width: 6),
                  Text(
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
              const SizedBox(height: 12),
              const Text(
                'Al-Mulk',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ayat 14',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          InkWell(
            onTap: () {},
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Daftar Surah',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF003527),
            ),
          ),
          InkWell(
            onTap: () {},
            child: Row(
              children: const [
                Text(
                  'Urutkan',
                  style: TextStyle(
                    color: Color(0xFF904D00),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 2),
                Icon(Icons.swap_vert, color: Color(0xFF904D00), size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurahItem(dynamic surah) {
    return InkWell(
      onTap: () {
        // Navigasi ke halaman detail baca ayat
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailSurahScreen(nomorSurah: surah['nomor']),
          ),
        );
      },
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
                fontFamily: 'Amiri',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
