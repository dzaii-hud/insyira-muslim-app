import 'package:flutter/material.dart';
import 'dart:math' as math;

class QiblaScreen extends StatelessWidget {
  const QiblaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildHeaderInfo(),
            const SizedBox(height: 50),
            _buildCompass(),
            const SizedBox(height: 50),
            _buildDegreesCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HEADER INFORMASI KOTAK ---
  Widget _buildHeaderInfo() {
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
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on_outlined, color: Colors.black87, size: 24),
            SizedBox(width: 8),
            Text(
              'Jakarta, Indonesia',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B4332),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RichText(
          text: const TextSpan(
            text: 'Jarak ke Makkah: ',
            style: TextStyle(color: Colors.grey, fontSize: 14),
            children: [
              TextSpan(
                text: '7,321 km',
                style: TextStyle(
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

  // --- WIDGET UI KOMPAS ---
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
              color: const Color(0xFF003527).withOpacity(0.04),
              blurRadius: 40,
              spreadRadius: 10,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Lingkaran Putus-putus / Garis Bantu (Outer)
            Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey.withOpacity(0.15),
                  width: 1,
                ),
              ),
            ),

            // Pola Geometris (Bintang Islami dari Kotak yang Diputar)
            _buildRotatedSquare(0),
            _buildRotatedSquare(math.pi / 6), // 30 derajat
            _buildRotatedSquare(math.pi / 3), // 60 derajat
            // Arah Mata Angin (U, S, T, B)
            const Positioned(
              top: 40,
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
              bottom: 40,
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
              right: 40,
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
              left: 40,
              child: Text(
                'B',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),

            // Jarum Kompas (Rotasi Dinamis)
            Transform.rotate(
              angle:
                  (55 *
                  math.pi /
                  180), // Mengarah ke kanan atas (sekitar 55 derajat)
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Kepala Jarum (Glow Indicator)
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
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1B4332).withOpacity(0.15),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                  ),
                  // Garis Jarum
                  Container(
                    width: 3,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF1B4332).withOpacity(0.6),
                          const Color(0xFF1B4332).withOpacity(0.0),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Penyeimbang bagian bawah agar poros rotasi tetap di tengah
                  const SizedBox(height: 134),
                ],
              ),
            ),

            // Poros Tengah (Center Hub)
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                  ),
                ],
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
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF904D00).withOpacity(0.3),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fungsi pembantu untuk menggambar kotak berputar (Geometris)
  Widget _buildRotatedSquare(double angle) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 210,
        height: 210,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.15), width: 1),
        ),
      ),
    );
  }

  // --- WIDGET KARTU DERAJAT DI BAWAH ---
  Widget _buildDegreesCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '292°',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B4332),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'BL',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87, // Warna gelap sesuai desain
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
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
