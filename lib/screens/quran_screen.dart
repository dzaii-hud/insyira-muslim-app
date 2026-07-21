import 'package:flutter/material.dart';
import 'dart:math' as math;

class QuranScreen extends StatelessWidget {
  const QuranScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 25),
          _buildLastReadBanner(),
          const SizedBox(height: 30),
          _buildSurahListHeader(),
          const SizedBox(height: 10),
          _buildSurahList(),
          const SizedBox(height: 40), // Jarak napas bawah layar
        ],
      ),
    );
  }

  // --- WIDGET PENCARIAN ---
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const TextField(
        decoration: InputDecoration(
          icon: Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          hintText: 'Cari Surah atau Ayat...',
          hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ),
    );
  }

  // --- WIDGET BANNER TERAKHIR DIBACA ---
  Widget _buildLastReadBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF003527), // Hijau sangat gelap sesuai desain
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF003527).withOpacity(0.2),
            blurRadius: 15,
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
                children: [
                  const Icon(Icons.history, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'TERAKHIR DIBACA',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
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
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ayat 14',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Text(
                  'Lanjutkan',
                  style: TextStyle(
                    color: Color(0xFF904D00), // Warna coklat/orange gelap
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, color: Color(0xFF904D00), size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HEADER DAFTAR SURAH ---
  Widget _buildSurahListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Daftar Surah',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF003527), // Hijau gelap
          ),
        ),
        TextButton.icon(
          onPressed: () {},
          icon: const Text(
            'Urutkan',
            style: TextStyle(color: Color(0xFF904D00), fontSize: 12),
          ),
          label: const Icon(
            Icons.swap_vert,
            color: Color(0xFF904D00),
            size: 16,
          ),
        ),
      ],
    );
  }

  // --- WIDGET LIST DAFTAR SURAH ---
  Widget _buildSurahList() {
    return Column(
      children: [
        _buildSurahItem(1, 'Al-Fatihah', 'PEMBUKAAN • 7 AYAT', 'الفاتحة'),
        _buildSurahItem(2, 'Al-Baqarah', 'SAPI BETINA • 286 AYAT', 'البقرة'),
        _buildSurahItem(
          3,
          'Ali \'Imran',
          'KELUARGA IMRAN • 200 AYAT',
          'آل عمران',
        ),
        _buildSurahItem(
          4,
          'An-Nisa',
          'WANITA • 176 AYAT',
          'النساء',
          isLast: true,
        ),
      ],
    );
  }

  // Widget Item Individual Surah
  Widget _buildSurahItem(
    int number,
    String title,
    String subtitle,
    String arabic, {
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Ikon Nomor Berputar (Rotated Square)
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: math.pi / 4, // Putar 45 derajat
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Text(
                  number.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003527),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Judul & Subjudul
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Teks Arab
          Text(
            arabic,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF003527),
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }
}
