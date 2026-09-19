import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:adhan/adhan.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'quran_screen.dart';
import 'qibla_screen.dart';
import 'kajian_screen.dart';
import 'dzikir_screen.dart';
import '../config.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../services/youtube_service.dart';
import '../widgets/kajian_card_background.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  final NotificationService _notificationService = NotificationService();

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
  String? lastReadMode;
  int? lastReadMushafPage;

  // YouTube data
  List<YouTubeVideo> _latestVideos = [];
  List<YouTubeVideo> _liveVideos = [];
  bool _isLoadingVideos = false;

  // ===== KAJIAN WIDGET DI HOME =====
  List<Kajian> _homeKajianList = [];
  bool _isLoadingKajianHome = true;

  // ===== FAWAIDH WIDGET DI HOME (data real dari API) =====
  List<Map<String, dynamic>> _homeFawaidhList = [];
  bool _isLoadingFawaidhHome = true;
  String _errorFawaidhHome = '';

  // Warna aksen untuk teks di atas foto
  static const Color _accentOnPhoto = Color(0xFF8BD6B6);
  static const Color _softWhite = Color(0xFFBEC9C2);

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
    _loadYouTubeData();
    _loadKajianHome();
    _loadFawaidhHome();
  }

  Future<void> _loadLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      lastReadSurahNumber = prefs.getInt('last_surah_number');
      lastReadSurah = prefs.getString('last_surah_name');
      lastReadAyat = prefs.getInt('last_ayat');
      lastReadMode = prefs.getString('last_read_mode');
      lastReadMushafPage = prefs.getInt('last_mushaf_page');
    });
  }

  Future<void> _loadKajianHome() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/kajian'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _homeKajianList = data.map((e) => Kajian.fromJson(e)).toList();
            _isLoadingKajianHome = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingKajianHome = false);
      }
    } catch (e) {
      debugPrint('Gagal load kajian home: $e');
      if (mounted) setState(() => _isLoadingKajianHome = false);
    }
  }

  Future<void> _loadFawaidhHome() async {
    if (mounted) setState(() => _errorFawaidhHome = '');
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/fawaidh'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _homeFawaidhList = data
                .map<Map<String, dynamic>>(
                  (e) => Map<String, dynamic>.from(e as Map),
                )
                .toList();
            _isLoadingFawaidhHome = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingFawaidhHome = false;
            _errorFawaidhHome = 'Gagal memuat fawaidh (${response.statusCode})';
          });
        }
      }
    } catch (e) {
      debugPrint('Gagal load fawaidh home: $e');
      if (mounted) {
        setState(() {
          _isLoadingFawaidhHome = false;
          _errorFawaidhHome = 'Tidak bisa terhubung ke server';
        });
      }
    }
  }

  Future<void> _loadYouTubeData() async {
    final service = YouTubeService();
    setState(() => _isLoadingVideos = true);
    try {
      final latest = await service.getLatestVideos(maxResults: 4);
      final live = await service.getLiveVideos();
      if (mounted) {
        setState(() {
          _latestVideos = latest;
          _liveVideos = live;
          _isLoadingVideos = false;
        });
      }
    } catch (e) {
      debugPrint('Error load YouTube: $e');
      if (mounted) {
        setState(() => _isLoadingVideos = false);
      }
    }
  }

  Future<void> _openYouTubeChannel() async {
    final Uri url = Uri.parse(
      'https://www.youtube.com/channel/UCxYY8T_y2mAgQQCjYvWwZdw',
    );
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Tidak dapat membuka YouTube'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  /// Membuka LANGSUNG video/live yang dipilih di aplikasi YouTube,
  /// bukan cuma halaman channel-nya.
  Future<void> _openYouTubeVideo(YouTubeVideo video) async {
    final String videoId = video.id.trim();

    // Kalau ID video kosong (data aneh dari API), baru fallback ke channel.
    if (videoId.isEmpty) {
      await _openYouTubeChannel();
      return;
    }

    // `watch?v=ID` berlaku untuk video biasa maupun siaran live,
    // dan otomatis dibuka oleh aplikasi YouTube kalau terpasang.
    final Uri url = Uri.parse('https://www.youtube.com/watch?v=$videoId');

    try {
      final bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await _openYouTubeChannel();
      }
    } catch (e) {
      debugPrint('Gagal membuka video YouTube: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Tidak dapat membuka video di YouTube'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
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
      _loadKajianHome();
      _loadFawaidhHome();
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
    context.push(AppRoutes.settings);
  }

  // ===== Fawaidh dibuka sebagai layar baru (bukan tab lagi) =====
  void _openFawaidhScreen() {
    context.push(AppRoutes.fawaidh).then((_) {
      // Segarkan daftar fawaidh di home setelah user kembali.
      _loadFawaidhHome();
    });
  }

  // =====================================================================
  // LOGIKA KAJIAN WIDGET DI HOME
  // =====================================================================
  Kajian? _getFeaturedKajianHome() {
    final now = DateTime.now();
    final todayStr =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final todayKajian =
        _homeKajianList.where((k) => k.tanggal == todayStr).toList()
          ..sort((a, b) => a.jamMulai.compareTo(b.jamMulai));

    if (todayKajian.isEmpty) return null;

    // 1. Cek yang sedang LIVE
    for (final k in todayKajian) {
      if (_isKajianOngoingHome(k)) return k;
    }

    // 2. Cek yang belum mulai
    final nowTime =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    for (final k in todayKajian) {
      if (k.jamMulai.compareTo(nowTime) > 0) return k;
    }

    return null;
  }

  // 👇 FIX: Filter out kajian yang sudah lewat
  List<Kajian> _getOtherKajianHome(Kajian? featured) {
    final now = DateTime.now();
    final todayStr =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final list = _homeKajianList.where((k) {
      // 1. Buang kajian yang tanggal-nya sudah lewat
      if (k.tanggal.compareTo(todayStr) < 0) return false;

      // 2. Buang featured dari list
      if (featured != null &&
          k.tanggal == featured.tanggal &&
          k.jamMulai == featured.jamMulai &&
          k.judul == featured.judul) {
        return false;
      }

      // 3. Kalau kajian hari ini, tapi jam selesai sudah lewat → skip
      if (k.tanggal == todayStr) {
        final nowTime =
            '${now.hour.toString().padLeft(2, '0')}:'
            '${now.minute.toString().padLeft(2, '0')}';
        if (k.jamSelesai.compareTo(nowTime) <= 0) return false;
      }

      return true;
    }).toList();

    // Sort ascending: tanggal dulu, lalu jam mulai
    list.sort((a, b) {
      final cmp = a.tanggal.compareTo(b.tanggal);
      if (cmp != 0) return cmp;
      return a.jamMulai.compareTo(b.jamMulai);
    });

    return list;
  }

  bool _hasKajianHariIniHome() {
    final now = DateTime.now();
    final todayStr =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return _homeKajianList.any((k) => k.tanggal == todayStr);
  }

  bool _isKajianOngoingHome(Kajian kajian) {
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    if (kajian.tanggal != today) return false;

    final nowTime =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    return nowTime.compareTo(kajian.jamMulai) >= 0 &&
        nowTime.compareTo(kajian.jamSelesai) <= 0;
  }

  String _getMonthShortHome(String tanggal) {
    final bulan = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MEI',
      'JUN',
      'JUL',
      'AGU',
      'SEP',
      'OKT',
      'NOV',
      'DES',
    ];
    if (tanggal.length < 7) return '';
    final month = int.tryParse(tanggal.substring(5, 7)) ?? 1;
    return bulan[month - 1];
  }

  // =====================================================================
  // KOMPONEN SECTION HOME
  //
  // Semua section di halaman Home memakai komponen di bawah ini supaya
  // tampilannya seragam dengan halaman Kajian & Fawaidh (aksen bar emas,
  // tombol "Lihat Semua" berbentuk pill, loading & empty state sejenis).
  // =====================================================================

  /// Jarak antar section di halaman Home.
  static const double _sectionGap = 28;

  /// Jarak antara judul section dan kontennya.
  static const double _sectionHeaderGap = 14;

  /// Header section standar.
  ///
  /// [onSeeAll] opsional — kalau diisi, tombol "Lihat Semua" muncul sebagai
  /// pill yang seragam di sisi kanan.
  Widget _buildSectionHeader({
    required String title,
    IconData? icon,
    String? badge,
    VoidCallback? onSeeAll,
    bool highlight = false,
  }) {
    final goldColor = AppColors.getGoldLeaf(context);
    final textColor = AppColors.getTextPrimary(context);
    final subTextColor = AppColors.getOnSurfaceVariant(context);

    return Row(
      children: [
        // Aksen bar (motif yang sama dengan halaman Kajian/Fawaidh).
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: highlight ? goldColor : AppColors.getPrimaryText(context),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        if (icon != null) ...[
          Icon(icon, size: 17, color: highlight ? goldColor : subTextColor),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: highlight ? goldColor : textColor,
            ),
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: goldColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: goldColor.withOpacity(0.4)),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: goldColor,
              ),
            ),
          ),
        ],
        if (onSeeAll != null) ...[
          const SizedBox(width: 8),
          _buildSeeAllButton(onSeeAll),
        ],
      ],
    );
  }

  /// Tombol "Lihat Semua" yang seragam di semua section Home.
  Widget _buildSeeAllButton(VoidCallback onPressed) {
    final goldColor = AppColors.getGoldLeaf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: goldColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: goldColor.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Lihat Semua',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: goldColor,
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 16, color: goldColor),
            ],
          ),
        ),
      ),
    );
  }

  /// Loading state yang seragam untuk section Home.
  Widget _buildSectionLoader(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Column(
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              color: AppColors.getGoldLeaf(context),
              strokeWidth: 2.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.getOnSurfaceVariant(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Empty state yang seragam untuk section Home.
  Widget _buildSectionEmptyNote(String text, {IconData? icon}) {
    final goldColor = AppColors.getGoldLeaf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceContainerLow(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getSurfaceVariant(context)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon ?? Icons.info_outline_rounded,
            size: 18,
            color: goldColor.withOpacity(0.85),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.getOnSurfaceVariant(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // WIDGET: KAJIAN DI HOME
  // =====================================================================
  Widget _buildKajianHomeWidget() {
    final featured = _getFeaturedKajianHome();
    final others = _getOtherKajianHome(featured);
    final hasToday = _hasKajianHariIniHome();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Jadwal Kajian',
          icon: Icons.event_note_rounded,
          onSeeAll: () => _onItemTapped(3),
        ),
        const SizedBox(height: _sectionHeaderGap),

        if (_isLoadingKajianHome)
          _buildSectionLoader('Memuat jadwal kajian...')
        else ...[
          if (featured != null)
            _buildKajianHomeFeaturedCard(featured)
          else
            _buildKajianHomeEmptyState(hasToday),

          if (others.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...others.take(2).map((k) => _buildKajianHomeRegularCard(k)),
          ],
        ],
      ],
    );
  }

  Widget _buildKajianHomeEmptyState(bool hasToday) {
    final surfaceColor = AppColors.getSurfaceContainerLow(context);
    final borderColor = AppColors.getSurfaceVariant(context);
    final goldColor = AppColors.getGoldLeaf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(
            hasToday ? Icons.check_circle_outline : Icons.event_busy_outlined,
            size: 32,
            color: goldColor.withOpacity(0.7),
          ),
          const SizedBox(height: 10),
          Text(
            hasToday
                ? 'Tidak ada lagi kajian di hari ini'
                : 'Tidak ada kajian hari ini',
            style: TextStyle(
              color: AppColors.getTextPrimary(context),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildKajianHomeFeaturedCard(Kajian kajian) {
    final hasPhoto = kajian.fotoUstadz != null && kajian.fotoUstadz!.isNotEmpty;
    final isLive = _isKajianOngoingHome(kajian);

    final surfaceColor = AppColors.getSurfaceContainerLow(context);
    final borderColor = AppColors.getSurfaceVariant(context);
    final goldColor = AppColors.getGoldLeaf(context);
    final textColor = AppColors.getTextPrimary(context);
    final subTextColor = AppColors.getOnSurfaceVariant(context);
    final primaryColor = AppColors.getPrimaryText(context);
    final shadowOpacity = Theme.of(context).brightness == Brightness.dark
        ? 0.25
        : 0.1;

    final titleColor = hasPhoto ? Colors.white : textColor;
    final ustadzColor = hasPhoto ? _accentOnPhoto : primaryColor;
    final metaColor = hasPhoto ? _softWhite : subTextColor;
    final cardRadius = BorderRadius.circular(20);

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: cardRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(shadowOpacity),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: cardRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // BACKGROUND (dijamin full-bleed, tidak ada sisa kosong/putih)
            if (hasPhoto)
              KajianCardBackground(photoUrl: kajian.fotoUstadz)
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [borderColor, surfaceColor],
                  ),
                ),
              ),

            // OVERLAY GELAP
            if (hasPhoto)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.85),
                    ],
                  ),
                ),
              ),

            // CONTENT
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isLive
                              ? goldColor
                              : (hasPhoto
                                    ? Colors.black.withOpacity(0.55)
                                    : goldColor.withOpacity(0.15)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLive
                                  ? Icons.play_arrow_rounded
                                  : Icons.schedule,
                              color: isLive
                                  ? const Color(0xFF00120B)
                                  : (hasPhoto ? _accentOnPhoto : goldColor),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isLive ? 'LIVE' : 'SEGERA',
                              style: TextStyle(
                                color: isLive
                                    ? const Color(0xFF00120B)
                                    : (hasPhoto ? _accentOnPhoto : goldColor),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: hasPhoto
                              ? Colors.black.withOpacity(0.4)
                              : Colors.black.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.bookmark_add_outlined,
                          color: hasPhoto ? _accentOnPhoto : textColor,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    kajian.judul,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      shadows: hasPhoto
                          ? const [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.person_outline, color: ustadzColor, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          kajian.ustadz,
                          style: TextStyle(
                            color: ustadzColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule, color: metaColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${kajian.jamMulai} - ${kajian.jamSelesai}',
                        style: TextStyle(color: metaColor, fontSize: 11),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.location_on_outlined,
                        color: metaColor,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          kajian.lokasi,
                          style: TextStyle(color: metaColor, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 👇 BORDER OVERLAY (di atas gambar, biar gambar full-bleed)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: cardRadius,
                    border: Border.all(color: borderColor),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKajianHomeRegularCard(Kajian kajian) {
    final hasPhoto = kajian.fotoUstadz != null && kajian.fotoUstadz!.isNotEmpty;

    final borderColor = AppColors.getSurfaceVariant(context);
    final goldColor = AppColors.getGoldLeaf(context);
    final textColor = AppColors.getTextPrimary(context);
    final subTextColor = AppColors.getOnSurfaceVariant(context);
    final primaryColor = AppColors.getPrimaryText(context);
    final shadowOpacity = Theme.of(context).brightness == Brightness.dark
        ? 0.25
        : 0.1;

    final titleColor = hasPhoto ? Colors.white : textColor;
    final ustadzColor = hasPhoto ? _accentOnPhoto : subTextColor;
    final metaColor = hasPhoto ? _softWhite : subTextColor;
    final cardRadius = BorderRadius.circular(14);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 90,
      decoration: BoxDecoration(
        borderRadius: cardRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(shadowOpacity),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: cardRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // BACKGROUND (dijamin full-bleed, tidak ada sisa kosong/putih)
            KajianCardBackground(
              photoUrl: hasPhoto ? kajian.fotoUstadz : null,
              overlayOpacity: hasPhoto ? 0.6 : 0,
              plainBaseColor: AppColors.getSurfaceContainerLow(context),
            ),

            // CONTENT
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: hasPhoto
                          ? Colors.black.withOpacity(0.5)
                          : borderColor,
                      borderRadius: BorderRadius.circular(10),
                      border: hasPhoto
                          ? Border.all(color: Colors.white.withOpacity(0.2))
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          kajian.tanggal.length >= 10
                              ? kajian.tanggal.substring(8, 10)
                              : '--',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: hasPhoto ? Colors.white : textColor,
                          ),
                        ),
                        Text(
                          _getMonthShortHome(kajian.tanggal),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: goldColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          kajian.judul,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                            shadows: hasPhoto
                                ? const [
                                    Shadow(
                                      color: Colors.black45,
                                      blurRadius: 3,
                                    ),
                                  ]
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          kajian.ustadz,
                          style: TextStyle(color: ustadzColor, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.schedule, color: goldColor, size: 11),
                            const SizedBox(width: 3),
                            Text(
                              '${kajian.jamMulai} - ${kajian.jamSelesai}',
                              style: TextStyle(
                                color: metaColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.bookmark_border,
                    color: hasPhoto
                        ? _accentOnPhoto.withOpacity(0.7)
                        : primaryColor,
                    size: 20,
                  ),
                ],
              ),
            ),

            // 👇 BORDER OVERLAY
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: cardRadius,
                    border: Border.all(color: borderColor),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // BUILD
  // =====================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
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
            _scaffoldKey.currentState?.openDrawer();
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
              label: 'Dzikir',
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
              const SizedBox(height: 22),
              _buildMenuGrid(),
              const SizedBox(height: _sectionGap),
              _buildKajianHomeWidget(),
              const SizedBox(height: _sectionGap),
              _buildFawaidhHome(),
              const SizedBox(height: _sectionGap),
              _buildLanjutMembaca(),
              const SizedBox(height: _sectionGap),
              _buildKajianOnline(),
              const SizedBox(height: _sectionGap),
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

  // --- MENU GRID (4 BUTTON) ---
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

  // --- SECTION FAWAIDH ASATIDZ (data real dari API /fawaidh) ---
  Widget _buildFawaidhHome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Fawaidh Asatidz',
          icon: Icons.auto_stories_rounded,
          badge: _homeFawaidhList.isEmpty ? null : '${_homeFawaidhList.length}',
          onSeeAll: _openFawaidhScreen,
        ),
        const SizedBox(height: _sectionHeaderGap),
        if (_isLoadingFawaidhHome)
          _buildFawaidhHomeLoading()
        else if (_homeFawaidhList.isEmpty)
          _buildFawaidhHomeEmpty()
        else
          ..._homeFawaidhList.take(3).map(_buildFawaidhHomeCard),
      ],
    );
  }

  Widget _buildFawaidhHomeCard(Map<String, dynamic> item) {
    final goldColor = AppColors.getGoldLeaf(context);
    final textColor = AppColors.getTextPrimary(context);
    final subTextColor = AppColors.getOnSurfaceVariant(context);

    final judul = (item['judul'] ?? 'Tanpa Judul').toString();
    final penulis = (item['penulis'] ?? 'Anonim').toString();
    final isi = (item['isi'] ?? '').toString().trim();

    return GestureDetector(
      onTap: _openFawaidhScreen,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceContainerLow(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.getSurfaceVariant(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.06,
              ),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Aksen emas di sisi kiri
                Container(width: 4, color: goldColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.getSurfaceVariant(context),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.auto_stories_outlined,
                                size: 18,
                                color: goldColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                judul,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  height: 1.3,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isi.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            isi,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: subTextColor,
                              height: 1.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: goldColor.withOpacity(0.18),
                              child: Text(
                                penulis.isNotEmpty
                                    ? penulis.characters.first.toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: goldColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                penulis,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: subTextColor,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: subTextColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFawaidhHomeLoading() {
    return Column(
      children: List.generate(
        2,
        (i) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.getSurfaceContainerLow(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.getSurfaceVariant(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _skeletonBar(width: 160, height: 14),
              const SizedBox(height: 12),
              _skeletonBar(width: double.infinity, height: 10),
              const SizedBox(height: 8),
              _skeletonBar(width: 220, height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skeletonBar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.getSurfaceVariant(context),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _buildFawaidhHomeEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceContainerLow(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getSurfaceVariant(context)),
      ),
      child: Column(
        children: [
          Icon(
            _errorFawaidhHome.isEmpty
                ? Icons.menu_book_outlined
                : Icons.cloud_off_rounded,
            color: AppColors.getGoldLeaf(context),
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            _errorFawaidhHome.isEmpty
                ? 'Belum ada fawaidh yang dibagikan'
                : _errorFawaidhHome,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.getOnSurfaceVariant(context),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              setState(() => _isLoadingFawaidhHome = true);
              _loadFawaidhHome();
            },
            icon: Icon(
              Icons.refresh,
              size: 18,
              color: AppColors.getGoldLeaf(context),
            ),
            label: Text(
              'Muat ulang',
              style: TextStyle(color: AppColors.getGoldLeaf(context)),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET LANJUT MEMBACA ---
  Widget _buildLanjutMembaca() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Lanjut Membaca',
          icon: Icons.bookmark_outline_rounded,
          onSeeAll: () => _onItemTapped(1),
        ),
        const SizedBox(height: _sectionHeaderGap),
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
                  // Alamatnya ikut berubah jadi /surah/{nomor} sehingga bisa
                  // dibagikan dan tahan refresh.
                  context
                      .push(
                        AppRoutes.surahDetail(
                          nomorSurah: freshNumber!,
                          ayat: isMushaf ? null : freshAyat,
                          mode: isMushaf ? 'mushaf' : null,
                          mushafPage: isMushaf ? freshPage : null,
                        ),
                      )
                      .then((_) => _loadLastRead());
                } else {
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

  // --- WIDGET KAJIAN ONLINE (4 VIDEO TERBARU) ---
  Widget _buildKajianOnline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Kajian Online',
          icon: Icons.play_circle_outline_rounded,
          badge: _latestVideos.isEmpty ? null : '${_latestVideos.length}',
          onSeeAll: () => _onItemTapped(3),
        ),
        const SizedBox(height: _sectionHeaderGap),
        if (_isLoadingVideos)
          _buildSectionLoader('Memuat video kajian...')
        else if (_latestVideos.isEmpty)
          _buildSectionEmptyNote(
            'Belum ada video kajian terbaru.',
            icon: Icons.video_library_outlined,
          )
        else
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _latestVideos.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final video = _latestVideos[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _openYouTubeVideo(video),
                  child: Container(
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
                        Stack(
                          children: [
                            Container(
                              height: 110,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                                image: video.thumbnailUrl.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(video.thumbnailUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                color: AppColors.getSurfaceVariant(context),
                              ),
                              child: video.thumbnailUrl.isEmpty
                                  ? Center(
                                      child: Icon(
                                        Icons.video_library,
                                        color: AppColors.getGoldLeaf(context),
                                        size: 40,
                                      ),
                                    )
                                  : null,
                            ),
                            // Badge tombol play: penanda kalau di-tap langsung
                            // membuka video ini di YouTube.
                            Positioned.fill(
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.55),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.7),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                video.title,
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
                                video.channelTitle,
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
        _buildSectionHeader(
          title: 'Saluran Live',
          icon: Icons.podcasts_rounded,
          highlight: _liveVideos.isNotEmpty,
          onSeeAll: _openYouTubeChannel,
        ),
        const SizedBox(height: _sectionHeaderGap),
        if (_isLoadingVideos)
          _buildSectionLoader('Memuat siaran langsung...')
        else if (_liveVideos.isEmpty)
          _buildSectionEmptyNote(
            'Tidak ada siaran langsung saat ini.',
            icon: Icons.podcasts_outlined,
          )
        else
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _liveVideos.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final video = _liveVideos[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _openYouTubeVideo(video),
                  child: Container(
                    width: 220,
                    decoration: BoxDecoration(
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
                      image: video.thumbnailUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(video.thumbnailUrl),
                              fit: BoxFit.cover,
                              colorFilter: ColorFilter.mode(
                                Colors.black.withOpacity(0.5),
                                BlendMode.darken,
                              ),
                            )
                          : null,
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
                                Icon(
                                  Icons.circle,
                                  color: Colors.white,
                                  size: 8,
                                ),
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
                          right: 12,
                          child: Text(
                            video.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
