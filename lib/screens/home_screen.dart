import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'detail_surah_screen.dart';
import 'quran_screen.dart';
import 'qibla_screen.dart';
import 'kajian_screen.dart';
import 'dzikir_screen.dart';
import 'settings_screen.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  final NotificationService _notificationService = NotificationService();
  // ... sisa variabel

  // --- VARIABEL DATA ASLI (JADWAL SHOLAT & GPS) ---
  String _locationName = "Mencari lokasi...";
  PrayerTimes? _prayerTimes;
  Prayer? _nextPrayer;
  Timer? _timer;
  String _countdownText = "--:--:--";
  String _activePrayer = "Dzuhur";

  // ====== VARIABEL MEMORI BACAAN ======
  String? lastReadSurah;
  int? lastReadSurahNumber;
  int? lastReadAyat;
  String? lastReadMode; // 'mushaf' atau 'translation'
  int? lastReadMushafPage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationService.init();
    _getLocationAndPrayerTimes();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCountdown();
    });

    _loadLastRead();
  }

  Future<void> _loadLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      lastReadSurahNumber = prefs.getInt('last_surah_number');
      lastReadSurah = prefs.getString('last_surah_name');
      lastReadAyat = prefs.getInt('last_ayat');
      // ====== [BARU] Tambahkan ini ======
      lastReadMode = prefs.getString('last_read_mode');
      lastReadMushafPage = prefs.getInt('last_mushaf_page');
      // =====================================
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
      _loadLastRead();
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
            backgroundColor: AppColors.getSurfaceContainerLow(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.getSurfaceVariant(context)),
            ),
            title: Text(
              'GPS Tidak Aktif',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            content: Text(
              'Jadwal sholat membutuhkan lokasi. Mohon aktifkan GPS di pengaturan HP kamu.',
              style: TextStyle(color: AppColors.getOnSurfaceVariant(context)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Batal',
                  style: TextStyle(
                    color: AppColors.getOnSurfaceVariant(context),
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.getGoldLeaf(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await Geolocator.openLocationSettings();
                },
                child: Text(
                  'Aktifkan GPS',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF00120B)
                        : Colors.white,
                  ),
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

    // Schedule notifications after getting prayer times
    if (_prayerTimes != null) {
      await _notificationService.schedulePrayerNotifications(_prayerTimes!);
    }
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

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey, // Tambahkan ini
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(
          context,
        ).scaffoldBackgroundColor.withOpacity(0.95),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.menu,
            color: AppColors.getPrimaryText(context),
            size: 28,
          ),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer(); // Pakai GlobalKey
          },
        ),
        leadingWidth: 56,
        title: Text(
          'Insyira',
          style: TextStyle(
            color: AppColors.getPrimaryText(context),
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications_none,
              color: AppColors.getPrimaryText(context),
              size: 28,
            ),
            onPressed: () {
              // Aksi untuk notifikasi
              // SnackBar untuk tombol notifikasi di AppBar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Tidak ada notifikasi baru',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor: const Color(0xFF003527),
                  behavior: SnackBarBehavior.floating,
                  margin: EdgeInsets.only(
                    bottom: MediaQuery.of(context).size.height - 200,
                    left: 20,
                    right: 20,
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      // ... sisa code sama
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF002117)
                    : const Color(0xFF00695C),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: const Icon(
                      Icons.mosque,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Insyira',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Muslim App',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.settings,
                color: AppColors.getPrimaryText(context),
              ),
              title: Text(
                'Pengaturan',
                style: TextStyle(color: AppColors.getTextPrimary(context)),
              ),
              onTap: () {
                Navigator.pop(context);
                _openSettings();
              },
            ),
            Divider(color: Theme.of(context).dividerColor),
            ListTile(
              leading: Icon(
                Icons.info,
                color: AppColors.getPrimaryText(context),
              ),
              title: Text(
                'Tentang',
                style: TextStyle(color: AppColors.getTextPrimary(context)),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Insyira Muslim App v1.0.0'),
                    backgroundColor: AppColors.getSurfaceVariant(context),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF00120B)
              : Colors.white,
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: AppColors.getGoldLeaf(context),
          unselectedItemColor: AppColors.getOnSurfaceVariant(context),
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book),
              label: 'Quran',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Qibla'),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month),
              label: 'Kajian',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome),
              label: 'Dhikr',
            ),
          ],
        ),
      ),
    );
  }

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
              const SizedBox(height: 25),
              _buildKajianOnline(),
              const SizedBox(height: 25),
              _buildSaluranLive(),
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
        return Center(
          key: const ValueKey('error'),
          child: Text(
            'Halaman tidak ditemukan',
            style: TextStyle(color: AppColors.getTextPrimary(context)),
          ),
        );
    }
  }

  // --- WIDGET HEADER SHOLAT ---
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
        color: AppColors.getSurfaceContainerLow(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getSurfaceVariant(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'SHALAT SELANJUTNYA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          nextPrayerNameString,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
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
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _countdownText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
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
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _locationName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
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
        color: isActive
            ? AppColors.getSurfaceVariant(context)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            name,
            style: TextStyle(
              color: isActive
                  ? AppColors.getGoldLeaf(context)
                  : AppColors.getOnSurfaceVariant(context),
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(
              color: isActive
                  ? AppColors.getGoldLeaf(context)
                  : AppColors.getTextPrimary(context),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET MENU TENGAH ---
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
                'Qibla',
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
                Icons.event_note,
                'Kajian',
                () => _onItemTapped(3),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildMenuItem(
                Icons.auto_awesome,
                'Dhikr',
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
        color: AppColors.getSurfaceContainerLow(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getSurfaceVariant(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
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
                  decoration: BoxDecoration(
                    color: AppColors.getSurfaceVariant(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.getGoldLeaf(context),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.getTextPrimary(context),
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
            Text(
              'Fawaidh Asatidz',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'Lihat Semua',
                style: TextStyle(color: AppColors.getGoldLeaf(context)),
              ),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.getSurfaceContainerLow(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.getSurfaceVariant(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  color: AppColors.getSurfaceVariant(context),
                ),
                child: Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    color: AppColors.getGoldLeaf(context),
                    size: 48,
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
                        color: AppColors.getGoldLeaf(context).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.getGoldLeaf(
                            context,
                          ).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        'Live Pukul 20:00',
                        style: TextStyle(
                          color: AppColors.getGoldLeaf(context),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tafsir Surat Al-Baqarah: Menghadapi Cobaan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kajian rutin mingguan membahas mendalam tafsir dan implementasi...',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.getOnSurfaceVariant(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.getSurfaceVariant(context),
                          radius: 14,
                          child: Text(
                            'UA',
                            style: TextStyle(
                              color: AppColors.getGoldLeaf(context),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ustadz Abdullah',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(context),
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
  // --- WIDGET LANJUT MEMBACA ---
  Widget _buildLanjutMembaca() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Lanjut Membaca',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            TextButton(
              onPressed: () {
                // Pindah ke Quran Screen (tab index 1)
                _onItemTapped(1);
              },
              child: Text(
                'Lihat Semua',
                style: TextStyle(color: AppColors.getGoldLeaf(context)),
              ),
            ),
          ],
        ),
        FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            String? freshSurah = lastReadSurah;
            int? freshNumber = lastReadSurahNumber;
            int? freshAyat = lastReadAyat;
            String? freshMode = lastReadMode;
            int? freshPage = lastReadMushafPage;

            if (snapshot.hasData) {
              freshSurah =
                  snapshot.data!.getString('last_surah_name') ?? lastReadSurah;
              freshNumber =
                  snapshot.data!.getInt('last_surah_number') ??
                  lastReadSurahNumber;
              freshAyat = snapshot.data!.getInt('last_ayat') ?? lastReadAyat;
              freshMode =
                  snapshot.data!.getString('last_read_mode') ?? lastReadMode;
              freshPage =
                  snapshot.data!.getInt('last_mushaf_page') ??
                  lastReadMushafPage;
            }

            final bool isMushaf = freshMode == 'mushaf';
            final bool hasBookmark =
                freshNumber != null &&
                (isMushaf ? freshPage != null : freshAyat != null);

            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (hasBookmark) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailSurahScreen(
                        nomorSurah: freshNumber!,
                        initialAyat: isMushaf ? null : freshAyat,
                        initialMode: isMushaf ? 'mushaf' : null,
                        initialMushafPage: isMushaf ? freshPage : null,
                      ),
                    ),
                  ).then((_) => _loadLastRead());
                } else {
                  // SnackBar untuk "Belum ada ayat yang ditandai"
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Belum ada ayat yang ditandai 🔖',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      backgroundColor: const Color(0xFF904D00),
                      behavior: SnackBarBehavior.floating,
                      margin: EdgeInsets.only(
                        bottom: MediaQuery.of(context).size.height - 100,
                        left: 20,
                        right: 20,
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.getSurfaceContainerLow(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.getSurfaceVariant(context),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: AppColors.getSurfaceVariant(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          isMushaf && hasBookmark
                              ? freshPage.toString()
                              : (freshNumber != null
                                    ? freshNumber.toString()
                                    : '-'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMushaf && hasBookmark
                                ? 'Halaman $freshPage'
                                : (freshSurah ?? 'Belum ada bacaan'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            !hasBookmark
                                ? 'Mulai membaca Al-Quran'
                                : (isMushaf
                                      ? (freshSurah ?? '')
                                      : 'Ayat $freshAyat'),
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.getOnSurfaceVariant(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.getGoldLeaf(context),
                      size: 16,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // --- WIDGET KAJIAN ONLINE ---
  Widget _buildKajianOnline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Kajian Online',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'Lihat Semua',
                style: TextStyle(color: AppColors.getPrimaryText(context)),
              ),
            ),
          ],
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              return Container(
                width: 260,
                decoration: BoxDecoration(
                  color: AppColors.getSurfaceContainerLow(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.getSurfaceVariant(context),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 110,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        color: AppColors.getSurfaceVariant(context),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.video_library,
                          color: AppColors.getGoldLeaf(context),
                          size: 40,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            index == 0
                                ? 'Riyadush Shalihin 2.103: Tidak Memberikan Wejangan Setiap Saat'
                                : 'Kitab Tauhid #4: Takut Syirik',
                            style: TextStyle(
                              color: AppColors.getTextPrimary(context),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ustadz Dr. Firanda Andirja, MA',
                            style: TextStyle(
                              color: AppColors.getOnSurfaceVariant(context),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- WIDGET SALURAN LIVE ---
  Widget _buildSaluranLive() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Saluran Live',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 2,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              bool isMadinah = index == 0;
              return Container(
                width: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.getSurfaceVariant(context),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 8),
                            SizedBox(width: 4),
                            Text(
                              'Live',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 40,
                      left: 12,
                      child: Text(
                        isMadinah ? 'Live Madinah' : 'Live Mekkah',
                        style: TextStyle(
                          color: AppColors.getTextPrimary(context),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Center(
                      child: Icon(
                        Icons.live_tv,
                        color: AppColors.getGoldLeaf(context),
                        size: 40,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
