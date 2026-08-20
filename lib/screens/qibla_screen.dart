import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  bool _isLoading = true;
  bool _hasPermission = false;

  String _locationName = "Mencari lokasi...";
  double _distanceToMecca = 0.0;
  double _qiblaDirection = 0.0;
  String _compassDirection = "";

  // Variabel penangkap arah HP (Wajib untuk mode AR)
  double? _heading;

  // --- VARIABEL KAMERA AR ---
  bool _isCameraMode = false;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  // Koordinat mutlak Ka'bah (Mekah)
  final double _kaabaLat = 21.422487;
  final double _kaabaLon = 39.826206;

  @override
  void initState() {
    super.initState();
    _initializeQibla();

    // Listener tambahan KHUSUS untuk pergerakan AR
    FlutterCompass.events?.listen((event) {
      if (mounted) {
        setState(() {
          _heading = event.heading;
        });
      }
    });
  }

  @override
  void dispose() {
    // Wajib: Matikan kamera saat pindah halaman agar baterai tidak boros
    _cameraController?.dispose();
    super.dispose();
  }

  // --- FUNGSI MENGHIDUPKAN/MEMATIKAN KAMERA AR ---
  Future<void> _toggleCameraMode() async {
    if (_isCameraMode) {
      setState(() {
        _isCameraMode = false;
      });
      return;
    }

    PermissionStatus status = await Permission.camera.request();

    if (status.isGranted) {
      try {
        final cameras = await availableCameras();
        final backCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
        );

        _cameraController = CameraController(
          backCamera,
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _cameraController!.initialize();

        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
            _isCameraMode = true;
          });
        }
      } catch (e) {
        debugPrint("Gagal menyalakan kamera: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Terjadi kesalahan saat membuka kamera'),
              backgroundColor: Color(0xFF003D2D), // surface-variant
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin kamera dibutuhkan untuk mode AR'),
            backgroundColor: Color(0xFF003D2D),
          ),
        );
      }
    }
  }

  Future<void> _initializeQibla() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _locationName = "GPS Belum Aktif";
          _isLoading = false;
        });
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _locationName = "Izin Lokasi Ditolak";
            _isLoading = false;
          });
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _locationName = "Izin Diblokir Permanen";
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _hasPermission = true;
      });
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    String cityName = await _getCityName(position.latitude, position.longitude);
    if (mounted) {
      setState(() {
        _locationName = cityName;
      });
    }

    double distanceInMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _kaabaLat,
      _kaabaLon,
    );
    _distanceToMecca = distanceInMeters / 1000;

    _qiblaDirection = _calculateQibla(position.latitude, position.longitude);
    _compassDirection = _getCompassDirectionText(_qiblaDirection);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String> _getCityName(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&accept-language=id',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'InsyiraApp'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        if (address != null) {
          String? city =
              address['city'] ??
              address['town'] ??
              address['county'] ??
              address['state'];
          String? country = address['country'];
          if (city != null && country != null) {
            return '$city, $country';
          } else if (country != null) {
            return country;
          }
        }
      }
    } catch (e) {
      debugPrint("Gagal memuat nama kota: $e");
    }
    return "Indonesia";
  }

  double _calculateQibla(double currentLat, double currentLon) {
    double latRad = currentLat * math.pi / 180.0;
    double lonRad = currentLon * math.pi / 180.0;
    double kaabaLatRad = _kaabaLat * math.pi / 180.0;
    double kaabaLonRad = _kaabaLon * math.pi / 180.0;

    double y = math.sin(kaabaLonRad - lonRad);
    double x =
        math.cos(latRad) * math.tan(kaabaLatRad) -
        math.sin(latRad) * math.cos(kaabaLonRad - lonRad);

    double qiblaRad = math.atan2(y, x);
    double qiblaDeg = (qiblaRad * 180.0 / math.pi);
    return (qiblaDeg + 360.0) % 360.0;
  }

  String _getCompassDirectionText(double degrees) {
    if (degrees >= 337.5 || degrees < 22.5) return 'U';
    if (degrees >= 22.5 && degrees < 67.5) return 'TL';
    if (degrees >= 67.5 && degrees < 112.5) return 'T';
    if (degrees >= 112.5 && degrees < 157.5) return 'TG';
    if (degrees >= 157.5 && degrees < 202.5) return 'S';
    if (degrees >= 202.5 && degrees < 247.5) return 'BD';
    if (degrees >= 247.5 && degrees < 292.5) return 'B';
    if (degrees >= 292.5 && degrees < 337.5) return 'BL';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // --- LAYER 1: BACKGROUND (Kamera atau Warna Dark Premium) ---
        if (_isCameraMode && _isCameraInitialized && _cameraController != null)
          Positioned.fill(child: CameraPreview(_cameraController!))
        else
          Positioned.fill(
            child: Container(color: const Color(0xFF022C22)),
          ), // deep-forest
        // --- LAYER 2: KONTEN UI UTAMA ---
        Positioned.fill(
          child: _isCameraMode
              ? _buildGoogleStyleARView()
              : _buildStandard2DView(),
        ),

        // --- LAYER 3: TOMBOL KAMERA AR (Pojok Kanan Atas) ---
        Positioned(
          top: 30,
          right: 20,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: _isCameraMode
                  ? const Color(0xFFFBBF24)
                  : const Color(0xFF002117), // gold-leaf vs surface-container
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF003D2D)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              tooltip: 'Mode Kamera AR',
              icon: Icon(
                _isCameraMode ? Icons.camera_alt : Icons.camera_alt_outlined,
                color: _isCameraMode
                    ? const Color(0xFF00120B)
                    : const Color(0xFF8BD6B6), // gelap vs primary
              ),
              onPressed: _toggleCameraMode,
            ),
          ),
        ),
      ],
    );
  }

  // =======================================================================
  // UI 1: KODE ASLIMU UNTUK MODE 2D BIASA (WARNA DISESUAIKAN)
  // =======================================================================

  Widget _buildStandard2DView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: _isLoading
            ? const SizedBox(
                height: 400,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFBBF24),
                  ), // gold-leaf
                ),
              )
            : Column(
                children: [
                  const SizedBox(height: 20),
                  _buildHeaderInfo(),
                  const SizedBox(height: 50),

                  if (_hasPermission) _buildCompass(),
                  if (!_hasPermission)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(
                        color: const Color(0xFF002117), // surface-container-low
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF003D2D)),
                      ),
                      child: const Text(
                        "Silakan aktifkan GPS dan Izin Lokasi",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),

                  const SizedBox(height: 50),
                  if (_hasPermission) _buildDegreesCard(),
                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    String distanceStr = _distanceToMecca
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );

    return Column(
      children: [
        const Text(
          'KIBLAT',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 3.0,
            color: Color(0xFF8BD6B6), // primary-fixed-dim
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_on_outlined,
              color: Color(0xFF8BD6B6),
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              _locationName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white, // Putih agar terang
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            text: 'Jarak ke Makkah: ',
            style: const TextStyle(
              color: Color(0xFFBEC9C2),
              fontSize: 14,
            ), // on-surface-variant
            children: [
              TextSpan(
                text: '$distanceStr km',
                style: const TextStyle(
                  color: Color(0xFFFBBF24), // gold-leaf
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompass() {
    return Center(
      child: Container(
        width: 320,
        height: 320,
        decoration: BoxDecoration(
          color: const Color(0xFF002117), // surface-container-low
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF003D2D),
            width: 2,
          ), // surface-variant
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 40,
              spreadRadius: 10,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: StreamBuilder<CompassEvent>(
          stream: FlutterCompass.events,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return const Center(
                child: Text(
                  'Sensor Error',
                  style: TextStyle(color: Colors.white),
                ),
              );
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFBBF24)),
              );
            }

            double? deviceHeading = snapshot.data?.heading;
            if (deviceHeading == null)
              return const Center(
                child: Text(
                  'Sensor Kompas Tidak Didukung',
                  style: TextStyle(color: Colors.white),
                ),
              );

            double compassRotationRad = -deviceHeading * (math.pi / 180);
            double qiblaRotationRad = _qiblaDirection * (math.pi / 180);

            return Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: compassRotationRad,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF003D2D), // surface-variant
                            width: 1,
                          ),
                        ),
                      ),
                      _buildRotatedSquare(0),
                      _buildRotatedSquare(math.pi / 6),
                      _buildRotatedSquare(math.pi / 3),

                      const Positioned(
                        top: 35,
                        child: Text(
                          'U',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color(0xFFFBBF24), // gold-leaf
                          ),
                        ),
                      ),
                      const Positioned(
                        bottom: 35,
                        child: Text(
                          'S',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Color(0xFFBEC9C2), // on-surface-variant
                          ),
                        ),
                      ),
                      const Positioned(
                        right: 35,
                        child: Text(
                          'T',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Color(0xFFBEC9C2),
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 35,
                        child: Text(
                          'B',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Color(0xFFBEC9C2),
                          ),
                        ),
                      ),

                      Transform.rotate(
                        angle: qiblaRotationRad,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF002117),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(
                                    0xFFFBBF24,
                                  ), // gold-leaf pointer
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFBBF24,
                                    ).withOpacity(0.3),
                                    blurRadius: 15,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Color(0xFFFBBF24),
                                size: 24,
                              ),
                            ),
                            Container(
                              width: 3,
                              height: 90,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFFBBF24), // gold-leaf
                                    Color(0x00FBBF24), // transparan
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 134),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF002117),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF003D2D)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24), // gold-leaf
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFBBF24).withOpacity(0.5),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRotatedSquare(double angle, [double size = 210]) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFF003D2D),
            width: 1,
          ), // surface-variant
        ),
      ),
    );
  }

  Widget _buildDegreesCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF002117), // surface-container-low
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF003D2D)), // surface-variant
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${_qiblaDirection.toStringAsFixed(0)}°',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // Putih
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _compassDirection,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFBBF24), // gold-leaf
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'ARAH KIBLAT',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2.5,
              color: Color(0xFFBEC9C2), // on-surface-variant
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // =======================================================================
  // UI 2: MODE KAMERA (PIN KA'BAH MELAYANG + KOMPAS ASLIMU DI BAWAH)
  // =======================================================================

  Widget _buildGoogleStyleARView() {
    double diff = _qiblaDirection - (_heading ?? 0);
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;

    double horizontalOffset = diff * 15;

    return Stack(
      children: [
        // 1. Jalur Emas dan Ikon Ka'bah Melayang
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(horizontalOffset, 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                _buildKaabaPin(),
                Container(
                  width: 60,
                  height: MediaQuery.of(context).size.height * 0.40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFFFBBF24), // Gold Leaf Glow
                        const Color(0xFFFBBF24).withOpacity(0.0),
                      ],
                    ),
                  ),
                  child: const Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Icon(
                        Icons.keyboard_double_arrow_up,
                        color: Color(
                          0xFF00120B,
                        ), // Tanda panah gelap agar terlihat di atas jalur emas
                        size: 50,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2. MENGGUNAKAN KOMPAS 2D ASLIMU DI BAGIAN BAWAH
        Positioned(bottom: 60, left: 0, right: 0, child: _buildAR2DCompass()),

        // 3. Panah Petunjuk Kiri/Kanan (Jika Ka'bah keluar layar)
        if (diff.abs() > 10)
          Positioned(
            left: diff < 0 ? 20 : null,
            right: diff > 0 ? 20 : null,
            top: MediaQuery.of(context).size.height / 2 - 30,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF002117).withOpacity(0.8), // Dark box
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFBBF24),
                ), // Gold border
              ),
              child: Icon(
                diff < 0 ? Icons.arrow_back_ios_new : Icons.arrow_forward_ios,
                color: const Color(0xFFFBBF24), // Gold icon
                size: 40,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildKaabaPin() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.location_on,
              size: 120,
              color: Color(0xFFFBBF24),
            ), // Pin Gold
            Positioned(
              top: 20,
              child: Container(
                width: 35,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black, // Ka'bah tetap hitam/emas
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      height: 5,
                      color: const Color(0xFFFBBF24),
                    ), // Garis emas ka'bah
                  ],
                ),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(
              0xFF002117,
            ).withOpacity(0.9), // surface container
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF003D2D)),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
          ),
          child: Text(
            '${_distanceToMecca.toStringAsFixed(0)} km',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAR2DCompass() {
    return Center(
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFF002117).withOpacity(0.85), // Dark transparan
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF003D2D)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10),
          ],
        ),
        child: StreamBuilder<CompassEvent>(
          stream: FlutterCompass.events,
          builder: (context, snapshot) {
            double? deviceHeading = snapshot.data?.heading;
            if (deviceHeading == null) return const SizedBox.shrink();

            double compassRotationRad = -deviceHeading * (math.pi / 180);
            double qiblaRotationRad = _qiblaDirection * (math.pi / 180);

            return Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: compassRotationRad,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF003D2D),
                            width: 1,
                          ),
                        ),
                      ),
                      _buildRotatedSquare(0, 120),
                      _buildRotatedSquare(math.pi / 6, 120),
                      _buildRotatedSquare(math.pi / 3, 120),

                      const Positioned(
                        top: 10,
                        child: Text(
                          'U',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFFFBBF24), // Gold
                          ),
                        ),
                      ),
                      const Positioned(
                        bottom: 10,
                        child: Text(
                          'S',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Color(0xFFBEC9C2),
                          ),
                        ),
                      ),
                      const Positioned(
                        right: 10,
                        child: Text(
                          'T',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Color(0xFFBEC9C2),
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 10,
                        child: Text(
                          'B',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Color(0xFFBEC9C2),
                          ),
                        ),
                      ),

                      Transform.rotate(
                        angle: qiblaRotationRad,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFF002117),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(
                                    0xFFFBBF24,
                                  ), // Gold pointer
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFBBF24,
                                    ).withOpacity(0.3),
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 2,
                              height: 45,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFFBBF24),
                                    Color(0x00FBBF24),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 69),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF002117),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF003D2D)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24), // Gold center
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFBBF24).withOpacity(0.5),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
