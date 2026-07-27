import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  // Koordinat mutlak Ka'bah (Mekah)
  final double _kaabaLat = 21.422487;
  final double _kaabaLon = 39.826206;

  @override
  void initState() {
    super.initState();
    _initializeQibla();
  }

  Future<void> _initializeQibla() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Cek apakah GPS hidup
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

    // 2. Cek izin aplikasi
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

    if (mounted)
      setState(() {
        _hasPermission = true;
      });

    // 3. Ambil koordinat GPS saat ini
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // 4. Ambil Nama Kota secara otomatis berdasarkan koordinat GPS
    String cityName = await _getCityName(position.latitude, position.longitude);
    if (mounted) {
      setState(() {
        _locationName = cityName;
      });
    }

    // 5. Hitung Jarak ke Mekah (dalam KM)
    double distanceInMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _kaabaLat,
      _kaabaLon,
    );
    _distanceToMecca = distanceInMeters / 1000;

    // 6. Hitung Arah/Sudut Kiblat (Bearing)
    _qiblaDirection = _calculateQibla(position.latitude, position.longitude);
    _compassDirection = _getCompassDirectionText(_qiblaDirection);

    if (mounted)
      setState(() {
        _isLoading = false;
      });
  }

  // --- FUNGSI MENGUBAH KOORDINAT JADI NAMA KOTA ---
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

  // --- RUMUS MATEMATIKA SUDUT KIBLAT ---
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

  // --- MENGUBAH DERAJAT JADI MATA ANGIN ---
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: _isLoading
            ? const SizedBox(
                height: 400,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF1B4332)),
                ),
              )
            : Column(
                children: [
                  const SizedBox(height: 20),
                  _buildHeaderInfo(),
                  const SizedBox(height: 50),

                  if (_hasPermission) _buildCompass(),
                  if (!_hasPermission)
                    const Text("Silakan aktifkan GPS dan Izin Lokasi"),

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
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_on_outlined,
              color: Colors.black87,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              _locationName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B4332),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            text: 'Jarak ke Makkah: ',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
            children: [
              TextSpan(
                text: '$distanceStr km',
                style: const TextStyle(
                  color: Color(0xFF1B4332),
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
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0x0A003527), // Setara opacity 0.04
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
              return const Center(child: Text('Sensor Error'));
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF1B4332)),
              );
            }

            double? deviceHeading = snapshot.data?.heading;
            if (deviceHeading == null)
              return const Center(child: Text('Sensor Kompas Tidak Didukung'));

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
                            color: const Color(0x269E9E9E),
                            width: 1,
                          ), // Setara grey dengan opacity 0.15
                        ),
                      ),
                      _buildRotatedSquare(0),
                      _buildRotatedSquare(math.pi / 6),
                      _buildRotatedSquare(math.pi / 3),

                      // --- INI BAGIAN YANG KELEBIHAN KURUNG KEMARIN ---
                      const Positioned(
                        top: 35,
                        child: Text(
                          'U',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color(0xFF1B4332),
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
                            color: Colors.grey,
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
                            color: Colors.grey,
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
                            color: Colors.grey,
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
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFD8EEDF),
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x261B4332),
                                    blurRadius: 15,
                                  ), // Setara opacity 0.15
                                ],
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
                                    Color(0x991B4332),
                                    Color(0x001B4332),
                                  ], // Setara opacity 0.6 ke 0.0
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
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0x1A9E9E9E),
                    ), // Setara grey opacity 0.1
                    boxShadow: const [
                      BoxShadow(color: Color(0x05000000), blurRadius: 10),
                    ], // Setara black opacity 0.02
                  ),
                  child: Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE8F5E9),
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Color(0x4D904D00), blurRadius: 5),
                        ], // Setara opacity 0.3
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

  Widget _buildRotatedSquare(double angle) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 210,
        height: 210,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x269E9E9E), width: 1),
        ),
      ),
    );
  }

  Widget _buildDegreesCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 20,
            offset: Offset(0, 8),
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
                  color: Color(0xFF1B4332),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _compassDirection,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
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
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
