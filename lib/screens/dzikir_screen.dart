import 'package:flutter/material.dart';

class DzikirScreen extends StatelessWidget {
  const DzikirScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // --- KONTEN UTAMA ---
        SingleChildScrollView(
          // Padding bawah ekstra besar agar konten tidak tertutup Audio Player
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 25),
              _buildSelectionCards(),
              const SizedBox(height: 30),
              _buildControls(),
              const SizedBox(height: 15),
              _buildDzikirCard(),
            ],
          ),
        ),

        // --- FLOATING AUDIO PLAYER ---
        Positioned(bottom: 20, left: 20, right: 20, child: _buildAudioPlayer()),
      ],
    );
  }

  // --- WIDGET HEADER ---
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dzikir Harian',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF003527),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Temukan ketenangan dalam mengingat Allah.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  // --- WIDGET PILIHAN PAGI & PETANG ---
  Widget _buildSelectionCards() {
    return Row(
      children: [
        // KARTU AKTIF (PAGI)
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF003527),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF003527).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Column(
              children: [
                Icon(Icons.wb_twilight, color: Color(0xFF95D3BA), size: 32),
                SizedBox(height: 12),
                Text(
                  'Pagi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Dzikir Pagi',
                  style: TextStyle(color: Color(0xFF95D3BA), fontSize: 10),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 15),
        // KARTU TIDAK AKTIF (PETANG)
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.nights_stay_outlined,
                  color: Color(0xFF003527),
                  size: 32,
                ),
                SizedBox(height: 12),
                Text(
                  'Petang',
                  style: TextStyle(
                    color: Color(0xFF003527),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Dzikir Petang',
                  style: TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- WIDGET KONTROL TEKS & PROGRESS ---
  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '1 dari 24',
            style: TextStyle(
              color: Color(0xFF003527),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () {},
              child: const Text(
                'A-',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text(
                'A+',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- WIDGET KARTU DZIKIR ---
  Widget _buildDzikirCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Garis Dekoratif Atas
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF904D00).withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header Judul & Bookmark
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AYATUL KURSI',
                style: TextStyle(
                  color: Color(0xFF904D00),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const Icon(Icons.bookmark_border, color: Colors.grey, size: 20),
            ],
          ),
          const SizedBox(height: 30),

          // Teks Arab
          const Text(
            'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF003527),
              height: 1.8,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 30),

          // Transliterasi (Kotak abu-abu)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(8),
              border: const Border(
                left: BorderSide(color: Color(0xFF003527), width: 4),
              ),
            ),
            child: Text(
              "Allahu la ilaha illa Huwa, Al-Haiyul-Qaiyum. La ta'khudhuhu sinatun wa la nawm...",
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Terjemahan
          Text(
            '"Allah, tidak ada tuhan selain Dia. Yang Maha Hidup, Yang terus-menerus mengurus (makhluk-Nya)..."',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 10),

          // Footer & Tombol Counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.repeat, color: Colors.grey, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Dibaca 1 kali',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
              // Tombol Bulat Counter
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: Color(0xFF003527),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '1',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- WIDGET FLOATING AUDIO PLAYER ---
  Widget _buildAudioPlayer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2E3132),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Info Audio
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dzikir Pagi Lengkap',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Mishary Alafasy',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                  ),
                ],
              ),
              // Kontrol Putar
              Row(
                children: [
                  const Icon(
                    Icons.replay_10,
                    color: Color(0xFF95D3BA),
                    size: 20,
                  ),
                  const SizedBox(width: 15),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF95D3BA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Color(0xFF003527),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 15),
                  const Icon(
                    Icons.forward_10,
                    color: Color(0xFF95D3BA),
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress Bar Line
          Row(
            children: [
              Text(
                '02:14',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: 0.15,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFFFDCC3),
                  ), // Warna cream/orange lembut
                  borderRadius: BorderRadius.circular(5),
                  minHeight: 4,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '15:30',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
