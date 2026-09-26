import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config.dart';
import '../services/web_compass.dart';
import '../theme/app_theme.dart'; // 👈 WAJIB IMPORT INI

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

  // --- VARIABEL KOMPAS WEB (peramban HP) ---
  /// Apakah izin sensor sudah diberikan. iOS 13+ mewajibkannya dan harus
  /// diminta lewat aksi user (tekan tombol), bukan otomatis saat halaman dibuka.
  bool _izinSensorWeb = false;

  /// HP-nya tidak mengirim data sensor sama sekali (mis. tanpa magnetometer).
  /// Dipakai supaya spinner tidak berputar selamanya.
  bool _sensorWebKosong = false;
  Timer? _penungguSensorWeb;

  // Koordinat mutlak Ka'bah (Mekah)
  final double _kaabaLat = 21.422487;
  final double _kaabaLon = 39.826206;

  @override
  void initState() {
    super.initState();
    _initializeQibla();

    // Listener tambahan KHUSUS untuk pergerakan AR.
    //
    // Di web, FlutterCompass tidak punya implementasi sehingga stream-nya
    // tidak ada; onError dipasang supaya errornya tidak jadi unhandled
    // exception. Arah kompas di web dibaca dari sensor peramban — lihat
    // [WebCompass] dan `_buildCompassWeb()`.
    if (!kIsWeb) {
      FlutterCompass.events?.listen(
        (event) {
          if (mounted) {
            setState(() {
              _heading = event.heading;
            });
          }
        },
        onError: (Object error) {
          debugPrint('Sensor kompas tidak tersedia: $error');
        },
      );
    } else if (WebCompass.perambanHp) {
      // Sensor peramban bisa saja tidak ada. Kalau dalam 6 detik tidak ada
      // data, tampilkan pesan yang jelas daripada spinner berputar terus.
      _penungguSensorWeb = Timer(const Duration(seconds: 6), () {
        if (mounted && WebCompass.arahTerakhir == null) {
          setState(() => _sensorWebKosong = true);
        }
      });
    }
  }

  @override
  void dispose() {
    // Wajib: Matikan kamera saat pindah halaman agar baterai tidak boros
    _cameraController?.dispose();
    _penungguSensorWeb?.cancel();
    super.dispose();
  }

  /// Pesan yang tampil ketika sensor kompas tidak bisa dipakai.
  ///
  /// Di browser pesannya dibedakan supaya user tidak bingung kenapa arah
  /// kiblat mati, padahal di HP bisa jalan.
  Widget _buildSensorUnavailable(BuildContext context, String fallbackText) {
    return _buildKotakInfo(
      ikon: Icons.explore_off_outlined,
      judul: kIsWeb ? 'Kompas tidak tersedia di peramban ini' : fallbackText,
      pesan: kIsWeb
          ? 'Buka halaman ini dari HP Android (Chrome) atau iPhone (Safari) '
                'supaya arah kiblat bisa dibaca otomatis.'
          : 'Perangkatmu belum mendukung sensor kompas.',
    );
  }

  /// Kotak pesan di tengah layar: ikon + judul + keterangan.
  Widget _buildKotakInfo({
    required IconData ikon,
    required String judul,
    required String pesan,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              ikon,
              size: 48,
              color: AppColors.getGoldLeaf(context).withValues(alpha: 0.8),
            ),
            const SizedBox(height: 14),
            Text(
              judul,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              pesan,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: AppColors.getOnSurfaceVariant(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Meminta izin sensor kompas peramban (wajib di iOS 13+).
  Future<void> _mintaIzinSensorWeb() async {
    final bool disetujui = await WebCompass.mintaIzin();
    if (!mounted) return;

    if (!disetujui) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Izin sensor ditolak. Arah kiblat tidak bisa dibaca otomatis.',
          ),
          backgroundColor: AppColors.getSurfaceVariant(context),
        ),
      );
      return;
    }

    setState(() => _izinSensorWeb = true);
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
            SnackBar(
              content: const Text('Terjadi kesalahan saat membuka kamera'),
              backgroundColor: AppColors.getSurfaceVariant(context),
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Izin kamera dibutuhkan untuk mode AR'),
            backgroundColor: AppColors.getSurfaceVariant(context),
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
      final response = await http
          .get(url, headers: {'User-Agent': 'InsyiraApp'})
          .timeout(AppConfig.requestTimeout);

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
            // 👈 UBAH: Gunakan warna scaffold background dinamis
            child: Container(color: Theme.of(context).scaffoldBackgroundColor),
          ),
        // --- LAYER 2: KONTEN UI UTAMA ---
        Positioned.fill(
          child: _isCameraMode
              ? _buildGoogleStyleARView()
              : _buildStandard2DView(),
        ),

        // --- LAYER 3: TOMBOL KAMERA AR (Pojok Kanan Atas) ---
        // Disembunyikan di web karena sensor kompas tidak tersedia di browser,
        // jadi overlay AR-nya tidak akan bisa menunjuk arah dengan benar.
        if (!kIsWeb)
          Positioned(
            top: 30,
            right: 20,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                // 👈 UBAH: Gunakan warna dinamis
                color: _isCameraMode
                    ? AppColors.getGoldLeaf(context)
                    : AppColors.getSurfaceContainerLow(context),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.getSurfaceVariant(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      Theme.of(context).brightness == Brightness.dark
                          ? 0.4
                          : 0.1,
                    ),
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
                      : AppColors.getPrimaryText(context), // 👈 UBAH
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
            ? SizedBox(
                height: 400,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.getGoldLeaf(context), // 👈 UBAH
                  ),
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
                        color: AppColors.getSurfaceContainerLow(
                          context,
                        ), // 👈 UBAH
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.getSurfaceVariant(context),
                        ), // 👈 UBAH
                      ),
                      child: Text(
                        "Silakan aktifkan GPS dan Izin Lokasi",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.getTextPrimary(context),
                        ), // 👈 UBAH
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
        Text(
          'KIBLAT',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 3.0,
            color: AppColors.getPrimaryText(context), // 👈 UBAH
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_on_outlined,
              color: AppColors.getPrimaryText(context), // 👈 UBAH
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              _locationName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context), // 👈 UBAH
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            text: 'Jarak ke Makkah: ',
            style: TextStyle(
              color: AppColors.getOnSurfaceVariant(context), // 👈 UBAH
              fontSize: 14,
            ),
            children: [
              TextSpan(
                text: '$distanceStr km',
                style: TextStyle(
                  color: AppColors.getGoldLeaf(context), // 👈 UBAH
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Bingkai bulat tempat piringan kompas digambar.
  ///
  /// Dipakai versi HP maupun versi web supaya tampilannya persis sama.
  Widget _bingkaiKompas(Widget isi) {
    return Center(
      child: Container(
        width: 320,
        height: 320,
        decoration: BoxDecoration(
          color: AppColors.getSurfaceContainerLow(context), // 👈 UBAH
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.getSurfaceVariant(context),
            width: 2,
          ), // 👈 UBAH
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                Theme.of(context).brightness == Brightness.dark ? 0.5 : 0.1,
              ),
              blurRadius: 40,
              spreadRadius: 10,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: isi,
      ),
    );
  }

  /// Kompas versi HP (Android/iOS) — memakai paket `flutter_compass`.
  Widget _buildCompass() {
    if (kIsWeb) return _buildCompassWeb();

    return _bingkaiKompas(
      StreamBuilder<CompassEvent>(
        stream: FlutterCompass.events,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildSensorUnavailable(context, 'Sensor Error');
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: AppColors.getGoldLeaf(context),
              ), // 👈 UBAH
            );
          }

          final double? deviceHeading = snapshot.data?.heading;
          if (deviceHeading == null) {
            return _buildSensorUnavailable(
              context,
              'Sensor Kompas Tidak Didukung',
            );
          }

          return _buildPiringanKompas(deviceHeading);
        },
      ),
    );
  }

  /// Kompas versi web.
  ///
  /// `flutter_compass` tidak punya implementasi web, jadi arah dibaca langsung
  /// dari sensor peramban lewat [WebCompass]. Hanya jalan kalau halaman dibuka
  /// dari HP — laptop/PC tidak punya sensor kompas.
  Widget _buildCompassWeb() {
    if (!WebCompass.perambanHp) {
      return _buildKotakInfo(
        ikon: Icons.desktop_windows_outlined,
        judul: 'Kompas hanya tersedia di HP',
        pesan:
            'Buka halaman ini dari HP Android atau iPhone untuk memakai '
            'penunjuk arah kiblat. Laptop/PC tidak punya sensor kompas.',
      );
    }

    if (!WebCompass.tersedia) {
      return _buildKotakInfo(
        ikon: Icons.explore_off_outlined,
        judul: 'Peramban tidak mendukung sensor',
        pesan:
            'Peramban ini tidak menyediakan data sensor orientasi. Coba buka '
            'dengan Google Chrome atau Safari.',
      );
    }

    // iOS 13+ wajib meminta izin lewat aksi user.
    if (WebCompass.perluIzin && !_izinSensorWeb) {
      return Column(
        children: [
          _buildKotakInfo(
            ikon: Icons.screen_rotation_outlined,
            judul: 'Izinkan Akses Sensor',
            pesan: 'iPhone meminta izin dulu sebelum arah kompas bisa dibaca.',
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _mintaIzinSensorWeb,
            icon: const Icon(Icons.sensors, size: 20),
            label: const Text('Aktifkan Sensor Kompas'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.getGoldLeaf(context),
              foregroundColor: const Color(0xFF00120B),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      );
    }

    if (_sensorWebKosong) {
      return _buildKotakInfo(
        ikon: Icons.explore_off_outlined,
        judul: 'Sensor kompas tidak terdeteksi',
        pesan:
            'HP ini sepertinya tidak punya sensor magnetometer. Arah kiblat '
            'tetap bisa dilihat dari angka derajat di bawah.',
      );
    }

    return _bingkaiKompas(
      StreamBuilder<double>(
        stream: WebCompass.aliran,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildSensorUnavailable(context, 'Sensor Error');
          }

          final double? heading = snapshot.data;
          if (heading == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.getGoldLeaf(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Menunggu sensor kompas...',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.getOnSurfaceVariant(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gerakkan HP membentuk angka 8',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.getOnSurfaceVariant(context),
                    ),
                  ),
                ],
              ),
            );
          }

          _penungguSensorWeb?.cancel();
          return _buildPiringanKompas(heading);
        },
      ),
    );
  }

  /// Piringan kompas beserta penunjuk arah kiblatnya.
  ///
  /// [deviceHeading] = arah yang sedang dihadapi HP (derajat, 0 = Utara).
  /// Dipakai bersama versi HP ([_buildCompass]) dan versi web
  /// ([_buildCompassWeb]) supaya gambarnya identik.
  Widget _buildPiringanKompas(double deviceHeading) {
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
                    color: AppColors.getSurfaceVariant(context), // 👈 UBAH
                    width: 1,
                  ),
                ),
              ),
              _buildRotatedSquare(0),
              _buildRotatedSquare(math.pi / 6),
              _buildRotatedSquare(math.pi / 3),

              Positioned(
                top: 35,
                child: Text(
                  'U',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.getGoldLeaf(context), // 👈 UBAH
                  ),
                ),
              ),
              Positioned(
                bottom: 35,
                child: Text(
                  'S',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.getOnSurfaceVariant(context), // 👈 UBAH
                  ),
                ),
              ),
              Positioned(
                right: 35,
                child: Text(
                  'T',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.getOnSurfaceVariant(context), // 👈 UBAH
                  ),
                ),
              ),
              Positioned(
                left: 35,
                child: Text(
                  'B',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.getOnSurfaceVariant(context), // 👈 UBAH
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
                        color: AppColors.getSurfaceContainerLow(
                          context,
                        ), // 👈 UBAH
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.getGoldLeaf(context), // 👈 UBAH
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.getGoldLeaf(
                              context,
                            ).withOpacity(0.3), // 👈 UBAH
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: AppColors.getGoldLeaf(context), // 👈 UBAH
                        size: 24,
                      ),
                    ),
                    Container(
                      width: 3,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.getGoldLeaf(context), // 👈 UBAH
                            AppColors.getGoldLeaf(
                              context,
                            ).withOpacity(0.0), // 👈 UBAH
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
            color: AppColors.getSurfaceContainerLow(context), // 👈 UBAH
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.getSurfaceVariant(context),
            ), // 👈 UBAH
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                  Theme.of(context).brightness == Brightness.dark ? 0.5 : 0.1,
                ),
                blurRadius: 10,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.getGoldLeaf(context), // 👈 UBAH
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.getGoldLeaf(
                      context,
                    ).withOpacity(0.5), // 👈 UBAH
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
            color: AppColors.getSurfaceVariant(context), // 👈 UBAH
            width: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildDegreesCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceContainerLow(context), // 👈 UBAH
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.getSurfaceVariant(context),
        ), // 👈 UBAH
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.4 : 0.1,
            ),
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
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context), // 👈 UBAH
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _compassDirection,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getGoldLeaf(context), // 👈 UBAH
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ARAH KIBLAT',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2.5,
              color: AppColors.getOnSurfaceVariant(context), // 👈 UBAH
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
                        AppColors.getGoldLeaf(context), // 👈 UBAH
                        AppColors.getGoldLeaf(
                          context,
                        ).withOpacity(0.0), // 👈 UBAH
                      ],
                    ),
                  ),
                  child: const Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Icon(
                        Icons.keyboard_double_arrow_up,
                        color: Color(0xFF00120B),
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
                color: AppColors.getSurfaceContainerLow(
                  context,
                ).withOpacity(0.8), // 👈 UBAH
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.getGoldLeaf(context), // 👈 UBAH
                ),
              ),
              child: Icon(
                diff < 0 ? Icons.arrow_back_ios_new : Icons.arrow_forward_ios,
                color: AppColors.getGoldLeaf(context), // 👈 UBAH
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
            Icon(
              Icons.location_on,
              size: 120,
              color: AppColors.getGoldLeaf(context), // 👈 UBAH
            ),
            Positioned(
              top: 20,
              child: Container(
                width: 35,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      height: 5,
                      color: AppColors.getGoldLeaf(context), // 👈 UBAH
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.getSurfaceContainerLow(
              context,
            ).withOpacity(0.9), // 👈 UBAH
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.getSurfaceVariant(context),
            ), // 👈 UBAH
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
          ),
          child: Text(
            '${_distanceToMecca.toStringAsFixed(0)} km',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(context), // 👈 UBAH
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
          color: AppColors.getSurfaceContainerLow(
            context,
          ).withOpacity(0.85), // 👈 UBAH
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.getSurfaceVariant(context),
          ), // 👈 UBAH
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                Theme.of(context).brightness == Brightness.dark ? 0.5 : 0.1,
              ),
              blurRadius: 10,
            ),
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
                            color: AppColors.getSurfaceVariant(
                              context,
                            ), // 👈 UBAH
                            width: 1,
                          ),
                        ),
                      ),
                      _buildRotatedSquare(0, 120),
                      _buildRotatedSquare(math.pi / 6, 120),
                      _buildRotatedSquare(math.pi / 3, 120),

                      Positioned(
                        top: 10,
                        child: Text(
                          'U',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.getGoldLeaf(context), // 👈 UBAH
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        child: Text(
                          'S',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppColors.getOnSurfaceVariant(
                              context,
                            ), // 👈 UBAH
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        child: Text(
                          'T',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppColors.getOnSurfaceVariant(
                              context,
                            ), // 👈 UBAH
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        child: Text(
                          'B',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppColors.getOnSurfaceVariant(
                              context,
                            ), // 👈 UBAH
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
                                color: AppColors.getSurfaceContainerLow(
                                  context,
                                ), // 👈 UBAH
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.getGoldLeaf(
                                    context,
                                  ), // 👈 UBAH
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.getGoldLeaf(
                                      context,
                                    ).withOpacity(0.3), // 👈 UBAH
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 2,
                              height: 45,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColors.getGoldLeaf(context), // 👈 UBAH
                                    AppColors.getGoldLeaf(
                                      context,
                                    ).withOpacity(0.0), // 👈 UBAH
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
                    color: AppColors.getSurfaceContainerLow(context), // 👈 UBAH
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.getSurfaceVariant(context),
                    ), // 👈 UBAH
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(
                          Theme.of(context).brightness == Brightness.dark
                              ? 0.4
                              : 0.1,
                        ),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.getGoldLeaf(context), // 👈 UBAH
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.getGoldLeaf(
                              context,
                            ).withOpacity(0.5), // 👈 UBAH
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
