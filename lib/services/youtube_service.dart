import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
  /// API key YouTube Data API v3.
  ///
  /// Sengaja TIDAK ditulis di dalam kode supaya tidak ikut ter-publish
  /// (seperti kasus client secret Quran Foundation sebelumnya).
  ///
  /// Isi lewat `--dart-define`:
  /// ```bash
  /// flutter run --dart-define=YOUTUBE_API_KEY=AIza...
  /// flutter build web --release --dart-define=YOUTUBE_API_KEY=AIza...
  /// ```
  ///
  /// WAJIB dibatasi dulu di Google Cloud Console supaya walau key-nya
  /// terbaca orang, tetap tidak bisa dipakai dari domain/aplikasi lain:
  ///   - Application restrictions : HTTP referrers (web) + Android apps
  ///   - API restrictions         : hanya "YouTube Data API v3"
  static const String _apiKey = String.fromEnvironment('YOUTUBE_API_KEY');

  static const String _channelId = 'UCxYY8T_y2mAgQQCjYvWwZdw';

  /// Apakah API key sudah dikonfigurasi.
  bool get isConfigured => _apiKey.trim().isNotEmpty;

  Future<List<YouTubeVideo>> getLatestVideos({int maxResults = 4}) async {
    if (!isConfigured) {
      debugPrint('YOUTUBE_API_KEY belum diisi — daftar video dilewati.');
      return [];
    }

    final url = Uri.parse('https://www.googleapis.com/youtube/v3/search')
        .replace(
          queryParameters: {
            'part': 'snippet',
            'channelId': _channelId,
            'order': 'date',
            'type': 'video',
            'eventType': 'completed',
            'maxResults': '$maxResults',
            'key': _apiKey,
          },
        );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final items = data['items'] as List<dynamic>? ?? [];
      return items
          .map((e) => YouTubeVideo.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Gagal ambil video: ${response.statusCode}');
    }
  }

  Future<List<YouTubeVideo>> getLiveVideos() async {
    if (!isConfigured) {
      debugPrint('YOUTUBE_API_KEY belum diisi — daftar live dilewati.');
      return [];
    }

    final url = Uri.parse('https://www.googleapis.com/youtube/v3/search')
        .replace(
          queryParameters: {
            'part': 'snippet',
            'channelId': _channelId,
            'type': 'video',
            'eventType': 'live',
            'maxResults': '5',
            'key': _apiKey,
          },
        );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final items = data['items'] as List<dynamic>? ?? [];
      return items
          .map((e) => YouTubeVideo.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Gagal ambil live: ${response.statusCode}');
    }
  }
}
