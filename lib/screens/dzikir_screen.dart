import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:insyira_muslim_app/widgets/floating_audio_player.dart';

class DzikirScreen extends StatefulWidget {
  const DzikirScreen({super.key});

  @override
  State<DzikirScreen> createState() => _DzikirScreenState();
}

class _DzikirScreenState extends State<DzikirScreen> {
  // State untuk mengontrol UI
  bool _isPagi = true; // true = Pagi, false = Sore
  double _arabFontSize = 26.0; // Ukuran font default

  // State untuk Data
  List<dynamic> _dzikirList = [];
  final Map<int, int> _counters = {}; // Menyimpan jumlah klik tasbih tiap item
  bool _isLoading = true;

  // --- State Baru: Mengontrol Audio Player ---
  Map<String, dynamic>?
  _activeAudio; // Menyimpan data dzikir yang sedang diputar

  @override
  void initState() {
    super.initState();
    _loadDzikirData();
  }

  // Fungsi membaca file JSON lokal
  Future<void> _loadDzikirData() async {
    try {
      final String response = await rootBundle.loadString('assets/dzikir.json');
      final data = await json.decode(response);

      setState(() {
        _dzikirList = _isPagi ? data['pagi'] : data['sore'];
        _counters.clear(); // Reset tasbih saat pindah waktu
        _isLoading = false;
        _activeAudio = null; // Sembunyikan player jika pindah tab Pagi/Petang
      });
    } catch (e) {
      debugPrint("Gagal memuat JSON: $e");
      setState(() => _isLoading = false);
    }
  }

  // Fungsi ganti tab Pagi/Petang
  void _toggleWaktu(bool isPagi) {
    if (_isPagi != isPagi) {
      setState(() {
        _isPagi = isPagi;
        _isLoading = true;
      });
      _loadDzikirData();
    }
  }

  // Fungsi ubah ukuran font
  void _changeFontSize(double step) {
    setState(() {
      _arabFontSize += step;
      // Batasi ukuran minimum dan maksimum
      if (_arabFontSize < 20.0) _arabFontSize = 20.0;
      if (_arabFontSize > 40.0) _arabFontSize = 40.0;
    });
  }

  // Fungsi tasbih (counter)
  void _incrementCounter(int index, int target) {
    setState(() {
      int current = _counters[index] ?? 0;
      if (current < target) {
        _counters[index] = current + 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // --- KONTEN UTAMA ---
        SingleChildScrollView(
          // Padding bawah dibuat dinamis agar list terbawah tidak tertutup audio player
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            _activeAudio != null ? 180 : 120,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 25),
              _buildSelectionCards(),
              const SizedBox(height: 30),
              _buildControls(),
              const SizedBox(height: 15),

              // Render List Dzikir Dinamis
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFBBF24),
                  ), // Gold
                )
              else if (_dzikirList.isEmpty)
                const Center(
                  child: Text(
                    "Data dzikir kosong",
                    style: TextStyle(color: Colors.white),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _dzikirList.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 20),
                  itemBuilder: (context, index) {
                    return _buildDzikirCard(_dzikirList[index], index);
                  },
                ),
            ],
          ),
        ),

        // --- FLOATING AUDIO PLAYER (Dinamis) ---
        if (_activeAudio != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tombol (X) Close untuk menyembunyikan player
                Padding(
                  padding: const EdgeInsets.only(right: 24.0, bottom: 4.0),
                  child: GestureDetector(
                    onTap: () => setState(() => _activeAudio = null),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF002117), // surface-container-low
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF003D2D)),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 20,
                        color: Color(0xFFBEC9C2), // on-surface-variant
                      ),
                    ),
                  ),
                ),
                FloatingAudioPlayer(
                  title: _activeAudio!['judul'] ?? 'Audio Dzikir',
                  audioUrl:
                      _activeAudio!['audio'] ??
                      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dzikir Harian',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white, // Putih agar kontras
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Temukan ketenangan dalam mengingat Allah.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFFBEC9C2),
          ), // on-surface-variant
        ),
      ],
    );
  }

  Widget _buildSelectionCards() {
    return Row(
      children: [
        // TAB PAGI
        Expanded(
          child: GestureDetector(
            onTap: () => _toggleWaktu(true),
            child: _buildTabCard(
              title: 'Pagi',
              subtitle: 'Dzikir Pagi',
              icon: Icons.wb_twilight,
              isActive: _isPagi,
            ),
          ),
        ),
        const SizedBox(width: 15),
        // TAB PETANG
        Expanded(
          child: GestureDetector(
            onTap: () => _toggleWaktu(false),
            child: _buildTabCard(
              title: 'Petang',
              subtitle: 'Dzikir Petang',
              icon: Icons.nights_stay_outlined,
              isActive: !_isPagi,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF003D2D)
            : const Color(0xFF002117), // Active: Surface Variant, Inactive: Low
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? const Color(0xFFFBBF24).withOpacity(0.5)
              : const Color(0xFF003D2D),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: isActive ? 20 : 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: isActive
                ? const Color(0xFFFBBF24)
                : const Color(0xFF8BD6B6), // Gold vs Primary
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: isActive
                  ? const Color(0xFFFBBF24)
                  : const Color(0xFFBEC9C2),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF003D2D), // surface-variant
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF8BD6B6).withOpacity(0.3)),
          ),
          child: Text(
            '${_dzikirList.length} Bacaan',
            style: const TextStyle(
              color: Color(0xFF8BD6B6), // primary
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () => _changeFontSize(-2.0),
              child: const Text(
                'A-',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _changeFontSize(2.0),
              child: const Text(
                'A+',
                style: TextStyle(
                  color: Colors.white,
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

  Widget _buildDzikirCard(Map<String, dynamic> dzikir, int index) {
    int target = dzikir['target'] ?? 1;
    int currentCount = _counters[index] ?? 0;
    bool isCompleted = currentCount >= target;

    bool isPlayingThis = _activeAudio != null && _activeAudio == dzikir;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF002117), // surface-container-low
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFFFBBF24)
              : const Color(0xFF003D2D), // Gold border if complete
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(
                  0xFFFBBF24,
                ).withOpacity(0.3), // Aksesn emas tipis
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // --- HEADER CARD ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  dzikir['judul'],
                  style: const TextStyle(
                    color: Color(0xFFFBBF24), // Gold Leaf
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _activeAudio = dzikir;
                      });
                    },
                    child: Icon(
                      isPlayingThis
                          ? Icons.volume_up_rounded
                          : Icons.play_circle_fill,
                      color: isPlayingThis
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFF8BD6B6), // Gold vs Primary
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.bookmark_border,
                    color: Color(0xFFBEC9C2), // on-surface-variant
                    size: 24,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 30),

          // --- ARABIC TEXT ---
          Text(
            dzikir['arab'],
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: _arabFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white, // Putih murni agar kontras
              fontFamily: 'LPMQ',
              height: 2.2,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 30),

          // --- LATIN TEXT ---
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF003D2D), // surface-variant
              borderRadius: BorderRadius.circular(8),
              border: const Border(
                left: BorderSide(
                  color: Color(0xFFFBBF24),
                  width: 4,
                ), // Gold line
              ),
            ),
            child: Text(
              dzikir['latin'],
              style: const TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Color(0xFFBEC9C2), // on-surface-variant
              ),
            ),
          ),
          const SizedBox(height: 20),

          // --- ARTI TEXT ---
          Text(
            dzikir['arti'],
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFBEC9C2), // on-surface-variant
              height: 1.5,
            ),
          ),
          const SizedBox(height: 30),
          const Divider(color: Color(0xFF003D2D)),
          const SizedBox(height: 10),

          // --- FOOTER & COUNTER TASBIH ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.repeat, color: Color(0xFFBEC9C2), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Dibaca $target kali',
                    style: const TextStyle(
                      color: Color(0xFFBEC9C2),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _incrementCounter(index, target),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFFFBBF24) // Gold
                        : const Color(0xFF003D2D), // surface-variant
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted
                          ? Colors.transparent
                          : const Color(0xFF8BD6B6).withOpacity(0.5),
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(
                            Icons.check,
                            color: Color(
                              0xFF00120B,
                            ), // Gelap (surface-lowest) agar kontras dengan Gold
                            size: 24,
                          )
                        : Text(
                            currentCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
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
}
