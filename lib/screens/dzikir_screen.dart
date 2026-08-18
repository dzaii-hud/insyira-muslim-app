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

              // Render List Dzikir Dinamis
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF003527),),
                )
              else if (_dzikirList.isEmpty)
                const Center(child: Text("Data dzikir kosong"))
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

        // --- FLOATING AUDIO PLAYER (Statis) ---
        Positioned(bottom: 20, left: 20, right: 20, child: _buildAudioPlayer()),
      ],
    );
  }

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

  // Widget Bantuan untuk Tab Kartu (Biar Kodenya Bersih)
  Widget _buildTabCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF003527) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isActive ? null : Border.all(color: Colors.grey.shade200),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF003527).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFF95D3BA) : const Color(0xFF003527),
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: isActive ? Colors.white : const Color(0xFF003527),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: isActive ? const Color(0xFF95D3BA) : Colors.grey,
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
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_dzikirList.length} Bacaan', // Menampilkan jumlah total dinamis
            style: const TextStyle(
              color: Color(0xFF003527),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () => _changeFontSize(-2.0), // Tombol Perkecil Font
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
              onPressed: () => _changeFontSize(2.0), // Tombol Perbesar Font
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

  Widget _buildDzikirCard(Map<String, dynamic> dzikir, int index) {
    int target = dzikir['target'] ?? 1;
    int currentCount = _counters[index] ?? 0;
    bool isCompleted = currentCount >= target;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted ? const Color(0xFF95D3BA) : Colors.grey.shade100,
        ), // Highlight hijau jika selesai
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

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  dzikir['judul'],
                  style: const TextStyle(
                    color: Color(0xFF904D00),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const Icon(Icons.bookmark_border, color: Colors.grey, size: 20),
            ],
          ),
          const SizedBox(height: 30),

          Text(
            dzikir['arab'],
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: _arabFontSize, // Font Size Dinamis!
              fontWeight: FontWeight.bold,
              color: const Color(0xFF003527),
              fontFamily: 'LPMQ',
              height: 2.2,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 30),

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
              dzikir['latin'],
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            dzikir['arti'],
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 10),

          // Footer & Tombol Counter Tasbih
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.repeat, color: Colors.grey, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Dibaca $target kali',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
                        ? const Color(0xFF95D3BA)
                        : const Color(
                            0xFF003527,
                          ), // Berubah warna jika target capai
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(
                            Icons.check,
                            color: Color(0xFF003527),
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
                  ),
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
