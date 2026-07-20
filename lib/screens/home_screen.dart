import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // --- VARIABEL UNTUK WAKTU SHOLAT ---
  // Kamu bisa ubah nilai ini menjadi 'Subuh', 'Dzuhur', 'Ashar', 'Maghrib', atau 'Isya'
  // untuk melihat gambarnya berubah.
  final String _activePrayer = 'Dzuhur'; // Contoh: Dzuhur

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Fungsi penentu gambar berdasarkan waktu sholat
  String _getBackgroundImage() {
    switch (_activePrayer.toLowerCase()) {
      case 'subuh':
        return 'assets/images/bg_subuh.png';
      case 'dzuhur':
        return 'assets/images/bg_zuhur.png';
      case 'ashar':
        return 'assets/images/bg_ashar.png';
      case 'maghrib':
        return 'assets/images/bg_maghrib.png';
      case 'isya':
        return 'assets/images/bg_isya.png';
      default:
        return 'assets/images/bg_zuhur.png';
    }
  }

  // Fungsi penentu jam sholat (dummy data untuk UI)
  String _getActiveTime() {
    switch (_activePrayer.toLowerCase()) {
      case 'subuh':
        return '04:30';
      case 'dzuhur':
        return '12:00';
      case 'ashar':
        return '15:15';
      case 'maghrib':
        return '18:00';
      case 'isya':
        return '19:15';
      default:
        return '--:--';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Insyira',
          style: TextStyle(
            color: Color(0xFF1B4332),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_none,
              color: Color(0xFF1B4332),
            ),
            onPressed: () {},
          ),
        ],
      ),

      body: _selectedIndex == 0
          ? SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPrayerTimeHeader(),
                  const SizedBox(height: 25),
                  _buildMenuGrid(),
                  const SizedBox(height: 25),
                ],
              ),
            )
          : Center(child: Text('Ini Halaman Index ke: $_selectedIndex')),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF1B4332),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Al-Quran',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Kiblat'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Kajian',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome),
            label: 'Dzikir',
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerTimeHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              image: DecorationImage(
                image: AssetImage(
                  _getBackgroundImage(),
                ), // MENGGUNAKAN GAMBAR DINAMIS
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                color: Colors.black.withOpacity(0.4),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SHOLAT BERIKUTNYA',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _activePrayer,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ), // TEKS DINAMIS
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _getActiveTime(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ), // WAKTU DINAMIS
                          Text(
                            'dalam 45 menit',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Jakarta, Indonesia',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTimeItem('Subuh', '04:30', _activePrayer == 'Subuh'),
                _buildTimeItem('Dzuhur', '12:00', _activePrayer == 'Dzuhur'),
                _buildTimeItem('Ashar', '15:15', _activePrayer == 'Ashar'),
                _buildTimeItem('Maghrib', '18:00', _activePrayer == 'Maghrib'),
                _buildTimeItem('Isya', '19:15', _activePrayer == 'Isya'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeItem(String name, String time, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFD8EEDF) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            name,
            style: TextStyle(
              color: isActive ? const Color(0xFF1B4332) : Colors.grey,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(
              color: isActive ? const Color(0xFF1B4332) : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMenuItem(Icons.menu_book, 'Al-Quran')),
            const SizedBox(width: 15),
            Expanded(child: _buildMenuItem(Icons.explore, 'Kiblat')),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(child: _buildMenuItem(Icons.calendar_month, 'Kajian')),
            const SizedBox(width: 15),
            Expanded(child: _buildMenuItem(Icons.auto_awesome, 'Dzikir')),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Color(0xFF1B4332), size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
