import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

class YouTubeVideo {
  final String id;
  final String title;
  final String thumbnailUrl;
  final String channelTitle;
  final DateTime publishedAt;
  final String liveBroadcastContent; // none, live, upcoming

  YouTubeVideo({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.channelTitle,
    required this.publishedAt,
    required this.liveBroadcastContent,
  });

  factory YouTubeVideo.fromJson(Map<String, dynamic> json) {
    final snippet = json['snippet'] ?? {};
    final thumbnails = snippet['thumbnails'] ?? {};
    final medium = thumbnails['medium'] ?? thumbnails['default'] ?? {};
    return YouTubeVideo(
      id: json['id'] is String
          ? json['id'] as String
          : (json['id']?['videoId'] as String? ?? ''),
      title: snippet['title'] ?? '',
      thumbnailUrl: medium['url'] ?? '',
      channelTitle: snippet['channelTitle'] ?? '',
      publishedAt:
          DateTime.tryParse(snippet['publishedAt'] ?? '') ?? DateTime.now(),
      liveBroadcastContent: snippet['liveBroadcastContent'] ?? 'none',
    );
  }
}

class YouTubeService {
  /// Alamat endpoint di backend kita sendiri, BUKAN googleapis.com.
  ///
  /// Kenapa lewat backend:
  ///
  /// 1. **Kuota.** Kuota YouTube Data API v3 hanya 10.000 unit per hari,
  ///    sementara `search.list` memakan 100 unit sekali panggil. Kalau
  ///    aplikasi memanggilnya langsung, kuota habis setelah sekitar 50 kali
  ///    halaman dibuka — dan videonya berhenti muncul tanpa pesan error.
  ///    Server memakai endpoint yang jauh lebih murah dan menyimpan hasilnya.
  ///
  /// 2. **Kunci.** API key tidak ikut ter-bundle di aplikasi. Untuk versi web
  ///    ini penting: seluruh isi `main.dart.js` bisa diunduh dan dibaca siapa
  ///    saja, dan `--dart-define` TIDAK menyembunyikan nilainya.
  ///
  /// 3. **CORS.** Tidak ada urusan header, karena alamatnya milik kita sendiri.
  Uri _endpoint(String path, [Map<String, String>? query]) {
    return Uri.parse(
      '${AppConfig.apiBaseUrl}/youtube/$path',
    ).replace(queryParameters: query);
  }

  Future<List<YouTubeVideo>> _fetch(Uri url) async {
    final response = await http.get(url).timeout(AppConfig.requestTimeout);

    if (response.statusCode != 200) {
      throw Exception('Gagal ambil data YouTube: ${response.statusCode}');
    }

    final data = json.decode(response.body);
    final items = data['items'] as List<dynamic>? ?? [];

    return items
        .map((e) => YouTubeVideo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Empat video terbaru dari channel Insyira TV.
  Future<List<YouTubeVideo>> getLatestVideos({int maxResults = 4}) {
    return _fetch(_endpoint('videos', {'max': '$maxResults'}));
  }

  /// Kajian yang sedang live.
  ///
  /// Hasilnya di-cache 30 menit di server (pengecekan live memakai kuota
  /// 100 unit sekali panggil), jadi bisa telat muncul sampai selama itu.
  Future<List<YouTubeVideo>> getLiveVideos() {
    return _fetch(_endpoint('live'));
  }
}
