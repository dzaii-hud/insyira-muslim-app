import 'package:flutter/material.dart';

class KajianScreen extends StatelessWidget {
  const KajianScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(),
            const SizedBox(height: 20),
            _buildDayFilter(),
            const SizedBox(height: 30),
            _buildFeaturedKajian(),
            const SizedBox(height: 30),
            _buildOtherSchedules(),
            const SizedBox(height: 20),
            _buildLoadMoreButton(),
            const SizedBox(height: 40), // Jarak napas bawah layar
          ],
        ),
      ),
    );
  }

  // --- WIDGET PENCARIAN ---
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
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
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          hintText: 'Cari ustadz, tema, atau masjid...',
          hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
          contentPadding: EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  // --- WIDGET FILTER HARI ---
  Widget _buildDayFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal, // Cukup ini saja
      child: Row(
        children: [
          _buildFilterChip('Hari Ini', isActive: true),
          _buildFilterChip('Besok'),
          _buildFilterChip('Senin'),
          _buildFilterChip('Selasa'),
          _buildFilterChip('Rabu'),
          _buildFilterChip('Kamis'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {bool isActive = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF003527) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isActive ? null : Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.grey.shade700,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
      ),
    );
  }

  // --- WIDGET KAJIAN UTAMA ---
  Widget _buildFeaturedKajian() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kajian Utama',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF003527),
          ),
        ),
        const SizedBox(height: 15),
        Container(
          height: 220,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFF003527),
            image: DecorationImage(
              image: const NetworkImage(
                'https://images.unsplash.com/photo-1584551246679-0daf3d275d0f?q=80&w=800&auto=format&fit=crop',
              ),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                const Color(0xFF003527).withOpacity(0.8), // Overlay hijau gelap
                BlendMode.srcOver,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF003527).withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF904D00), // Warna orange/coklat
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.live_tv, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bookmark_border,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tafsir Ibnu Katsir: Surat Al-Kahf & Keutamaannya',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        color: Color(0xFF95D3BA),
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Ustadz Dr. Syafiq Riza Basalamah',
                        style: TextStyle(
                          color: Color(0xFF95D3BA),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        color: Colors.white70,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '18:30 - Selesai',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Colors.white54,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(
                        Icons.location_on_outlined,
                        color: Colors.white70,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Masjid Raya Insyira',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- WIDGET JADWAL LAINNYA ---
  Widget _buildOtherSchedules() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Jadwal Kajian Lainnya',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF003527),
          ),
        ),
        const SizedBox(height: 15),
        _buildScheduleItem(
          '13',
          'OKT',
          'Adab Menuntut Ilmu',
          'Ustadz Nuzul Dzikri',
          '05:00 - 06:00 (Ba\'da Fajr)',
        ),
        const SizedBox(height: 12),
        _buildScheduleItem(
          '14',
          'OKT',
          'Fiqih Muamalah Kontemporer',
          'Ustadz Erwandi Tarmizi',
          '16:00 - 17:30',
        ),
        const SizedBox(height: 12),
        _buildScheduleItem(
          '15',
          'OKT',
          'Siroh Nabawiyah',
          'Ustadz Firanda Andirja',
          '09:00 - 11:00',
        ),
      ],
    );
  }

  Widget _buildScheduleItem(
    String date,
    String month,
    String title,
    String ustadz,
    String time,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          // Kotak Tanggal
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003527),
                  ),
                ),
                Text(
                  month,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF904D00),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          // Info Kajian
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003527),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ustadz,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      color: Color(0xFF904D00),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Ikon Bookmark
          IconButton(
            icon: const Icon(Icons.bookmark_border, color: Colors.grey),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // --- WIDGET TOMBOL MUAT LEBIH BANYAK ---
  Widget _buildLoadMoreButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Color(0xFF003527), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Text(
          'Muat Lebih Banyak',
          style: TextStyle(
            color: Color(0xFF003527),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
