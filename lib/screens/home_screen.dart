import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';

import 'quran_screen.dart';
import 'qibla_screen.dart';
import 'kajian_screen.dart';
import 'dzikir_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  // --- VARIABEL DATA ASLI (JADWAL SHOLAT & GPS) ---
  String _locationName = "Mencari lokasi...";
  PrayerTimes? _prayerTimes;
  Prayer? _nextPrayer;
  Timer? _timer;
  String _countdownText = "--:--:--";
  String _activePrayer = "Dzuhur";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getLocationAndPrayerTimes();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCountdown();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_locationName == "GPS belum aktif" ||
          _locationName == "Izin lokasi ditolak") {
        _getLocationAndPrayerTimes();
      }
    }
  }

  Future<void> _getLocationAndPrayerTimes() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      setState(() => _locationName = "GPS belum aktif");

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'GPS Tidak Aktif',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF003527),
              ),
            ),
            content: const Text(
              'Jadwal sholat membutuhkan lokasi. Mohon aktifkan GPS di pengaturan HP kamu.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Batal',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003527),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await Geolocator.openLocationSettings();
                },
                child: const Text(
                  'Aktifkan GPS',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _locationName = "Izin lokasi ditolak");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _locationName = "Izin lokasi diblokir");
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    try {
      final Geocoding geocoding = Geocoding();
      List<Placemark> placemarks = await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        setState(() {
          _locationName = "${placemarks[0].locality}, ${placemarks[0].country}";
        });
      }
    } catch (e) {
      setState(() => _locationName = "Koordinat ditemukan");
    }

    final coordinates = Coordinates(position.latitude, position.longitude);
    final params = CalculationMethod.singapore.getParameters();
    params.madhab = Madhab.shafi;

    setState(() {
      _prayerTimes = PrayerTimes.today(coordinates, params);
      _nextPrayer = _prayerTimes?.nextPrayer();
      _activePrayer = _getPrayerName(
        _prayerTimes?.currentPrayer() ?? Prayer.fajr,
      );
    });
  }

  void _updateCountdown() {
    if (_prayerTimes == null ||
        _nextPrayer == null ||
        _nextPrayer == Prayer.none)
      return;

    final nextPrayerTime = _prayerTimes!.timeForPrayer(_nextPrayer!);
    if (nextPrayerTime != null) {
      final now = DateTime.now();
      final diff = nextPrayerTime.difference(now);

      if (diff.isNegative) {
        setState(() {
          _nextPrayer = _prayerTimes!.nextPrayer();
          _activePrayer = _getPrayerName(
            _prayerTimes?.currentPrayer() ?? Prayer.fajr,
          );
        });
      } else {
        String hours = diff.inHours.toString().padLeft(2, '0');
        String minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
        String seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');

        setState(() {
          _countdownText = "-$hours:$minutes:$seconds";
        });
      }
    }
  }

  String _getPrayerName(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr:
        return "Subuh";
      case Prayer.sunrise:
        return "Terbit";
      case Prayer.dhuhr:
        return "Dzuhur";
      case Prayer.asr:
        return "Ashar";
      case Prayer.maghrib:
        return "Maghrib";
      case Prayer.isha:
        return "Isya";
      default:
        return "Subuh";
    }
  }

  String _getBackgroundMap() {
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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

      // --- BODY DENGAN ANIMASI TRANSISI ---
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.05),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: _buildBodyContent(),
      ),

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

  // --- FUNGSI PENGATUR HALAMAN ---
  Widget _buildBodyContent() {
    switch (_selectedIndex) {
      case 0:
        return SingleChildScrollView(
          key: const ValueKey(0),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPrayerTimeHeader(),
              const SizedBox(height: 25),
              _buildMenuGrid(),
              const SizedBox(height: 25),
              _buildKajianHariIni(),
              const SizedBox(height: 20),
              _buildLanjutMembaca(),
              const SizedBox(height: 40),
            ],
          ),
        );
      case 1:
        return const QuranScreen(key: ValueKey(1));
      case 2:
        return const QiblaScreen(key: ValueKey(2));
      case 3:
        return const KajianScreen(key: ValueKey(3));
      case 4:
        return const DzikirScreen(key: ValueKey(4));
      default:
        return const Center(
          key: ValueKey('error'),
          child: Text('Halaman tidak ditemukan'),
        );
    }
  }

  // --- WIDGET HEADER SHOLAT DINAMIS ---
  Widget _buildPrayerTimeHeader() {
    String nextPrayerTimeString = "--:--";
    String nextPrayerNameString = "Memuat...";

    if (_prayerTimes != null &&
        _nextPrayer != null &&
        _nextPrayer != Prayer.none) {
      final time = _prayerTimes!.timeForPrayer(_nextPrayer!);
      if (time != null) {
        nextPrayerTimeString = DateFormat('HH:mm').format(time);
        nextPrayerNameString = _getPrayerName(_nextPrayer!);
      }
    }

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
                image: AssetImage(_getBackgroundMap()),
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
                            nextPrayerNameString,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            nextPrayerTimeString,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _countdownText,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _locationName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
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
                _buildTimeItem(
                  'Subuh',
                  _prayerTimes != null
                      ? DateFormat('HH:mm').format(_prayerTimes!.fajr)
                      : '--:--',
                  _activePrayer == 'Subuh',
                ),
                _buildTimeItem(
                  'Dzuhur',
                  _prayerTimes != null
                      ? DateFormat('HH:mm').format(_prayerTimes!.dhuhr)
                      : '--:--',
                  _activePrayer == 'Dzuhur',
                ),
                _buildTimeItem(
                  'Ashar',
                  _prayerTimes != null
                      ? DateFormat('HH:mm').format(_prayerTimes!.asr)
                      : '--:--',
                  _activePrayer == 'Ashar',
                ),
                _buildTimeItem(
                  'Maghrib',
                  _prayerTimes != null
                      ? DateFormat('HH:mm').format(_prayerTimes!.maghrib)
                      : '--:--',
                  _activePrayer == 'Maghrib',
                ),
                _buildTimeItem(
                  'Isya',
                  _prayerTimes != null
                      ? DateFormat('HH:mm').format(_prayerTimes!.isha)
                      : '--:--',
                  _activePrayer == 'Isya',
                ),
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

  // --- WIDGET MENU TENGAH (Bisa Diklik) ---
  Widget _buildMenuGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMenuItem(
                Icons.menu_book,
                'Al-Quran',
                () => _onItemTapped(1),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildMenuItem(
                Icons.explore,
                'Kiblat',
                () => _onItemTapped(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildMenuItem(
                Icons.calendar_month,
                'Kajian',
                () => _onItemTapped(3),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildMenuItem(
                Icons.auto_awesome,
                'Dzikir',
                () => _onItemTapped(4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: const Color(0xFF1B4332), size: 28),
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
          ),
        ),
      ),
    );
  }

  // --- WIDGET KAJIAN HARI INI ---
  Widget _buildKajianHariIni() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Kajian Hari Ini',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text(
                'Lihat Semua',
                style: TextStyle(color: Color(0xFF1B4332)),
              ),
            ),
          ],
        ),
        Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 150,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  image: DecorationImage(
                    image: NetworkImage(
                      'https://images.unsplash.com/photo-1590076215667-875d4efbf2b9?q=80&w=600&auto=format&fit=crop',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFE932C).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Live Pukul 20:00',
                        style: TextStyle(
                          color: Color(0xFFD97706),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tafsir Surat Al-Baqarah: Menghadapi Cobaan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kajian rutin mingguan membahas mendalam tafsir dan implementasi...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 15),
                    const Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Color(0xFFD8EEDF),
                          radius: 14,
                          child: Text(
                            'UA',
                            style: TextStyle(
                              color: Color(0xFF1B4332),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Ustadz Abdullah',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- WIDGET LANJUT MEMBACA ---
  Widget _buildLanjutMembaca() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Lanjut Membaca',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text(
                'Lihat Semua',
                style: TextStyle(color: Color(0xFF1B4332)),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(16),
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
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    '67',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B4332),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Al-Mulk',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ayat 12 • 45% Selesai',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'الملك',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 60,
                    child: LinearProgressIndicator(
                      value: 0.45,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF904D00),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
