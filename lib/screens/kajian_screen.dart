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
            // Pencarian dan Filter Hari dihapus sesuai permintaan
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

  // --- WIDGET KAJIAN UTAMA (HARI INI) ---
  Widget _buildFeaturedKajian() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kajian Hari Ini',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white, // Teks putih
          ),
        ),
        const SizedBox(height: 15),
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFF002117), // surface-container-low
            border: Border.all(
              color: const Color(0xFF003D2D),
            ), // surface-variant
            image: DecorationImage(
              image: const NetworkImage(
                'https://images.unsplash.com/photo-1584551246679-0daf3d275d0f?q=80&w=800&auto=format&fit=crop',
              ),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.5), // Dark overlay agar teks terbaca
                BlendMode.darken,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
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
                        color: const Color(
                          0xFFFBBF24,
                        ).withOpacity(0.15), // Efek Gold transparan
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFBBF24).withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.live_tv,
                            color: Color(0xFFFBBF24),
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Color(0xFFFBBF24), // Gold Leaf
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF003D2D), // surface-variant
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bookmark_border,
                        color: Color(0xFFBEC9C2), // on-surface-variant
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
                          color: Color(0xFF8BD6B6), // Primary Mint
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Ustadz Dr. Syafiq Riza Basalamah',
                          style: TextStyle(
                            color: Color(0xFF8BD6B6),
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
                          color: Color(0xFFBEC9C2), // on-surface-variant
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '18:30 - Selesai',
                          style: TextStyle(
                            color: Color(0xFFBEC9C2),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Color(0xFFBEC9C2),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.location_on_outlined,
                          color: Color(0xFFBEC9C2),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Masjid Raya Insyira',
                          style: TextStyle(
                            color: Color(0xFFBEC9C2),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
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
            color: Colors.white, // Teks Putih
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
        color: const Color(0xFF002117), // surface-container-low
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4), // Dark shadow
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFF003D2D)), // surface-variant
      ),
      child: Row(
        children: [
          // Kotak Tanggal
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF003D2D), // surface-variant
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
                    color: Colors.white, // Teks Putih
                  ),
                ),
                Text(
                  month,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFBBF24), // Gold Leaf
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
                    color: Colors.white, // Teks Putih
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ustadz,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFBEC9C2), // on-surface-variant
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      color: Color(0xFFFBBF24), // Gold Leaf
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFFBEC9C2), // on-surface-variant
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
            icon: const Icon(Icons.bookmark_border, color: Color(0xFFBEC9C2)),
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
          side: const BorderSide(
            color: Color(0xFFFBBF24),
            width: 1.5,
          ), // Gold Leaf border
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Text(
          'Muat Lebih Banyak',
          style: TextStyle(
            color: Color(0xFFFBBF24), // Gold Leaf text
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
