import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_share/core/models/platform_type.dart';

class OdesliResult {
  final String? title;
  final String? artist;
  final String? artworkUrl;
  final Map<PlatformType, String> directPlatformUrls;

  const OdesliResult({
    this.title,
    this.artist,
    this.artworkUrl,
    required this.directPlatformUrls,
  });
}

class OdesliApiSource {
  static const String _apiBaseUrl = 'https://api.song.link/v1-alpha.1/links';
  static final http.Client _client = http.Client();

  static const Map<String, PlatformType> _platformMap = {
    'spotify': PlatformType.spotify,
    'appleMusic': PlatformType.appleMusic,
    'youtubeMusic': PlatformType.youtubeMusic,
    'youtube': PlatformType.youtube,
    'amazonMusic': PlatformType.amazonMusic,
    'amazon': PlatformType.amazonMusic,
  };

  static Future<OdesliResult?> fetchLinks(String url) async {
    // 1. Try public API endpoint first
    try {
      final uri = Uri.parse(_apiBaseUrl).replace(queryParameters: {'url': url});
      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': 'PulseShare/2.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseApiResponse(data);
      }
    } catch (_) {}

    // 2. Fallback: Parse Songlink Next.js data
    try {
      final webUrl = 'https://song.link/$url';
      final response = await _client.get(
        Uri.parse(webUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14)',
          'Accept': 'text/html,application/xhtml+xml',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return _parseWebPage(response.body);
      }
    } catch (e) {
      debugPrint('OdesliApiSource scrape fallback error: $e');
    }

    return null;
  }

  static OdesliResult? _parseApiResponse(Map<String, dynamic> data) {
    final linksByPlatform = data['linksByPlatform'] as Map<String, dynamic>? ?? {};
    final platformUrls = <PlatformType, String>{};

    for (final entry in linksByPlatform.entries) {
      final platform = _platformMap[entry.key];
      if (platform != null) {
        final platformData = entry.value as Map<String, dynamic>?;
        final linkUrl = platformData?['url'] as String?;
        if (linkUrl != null && linkUrl.isNotEmpty) {
          platformUrls[platform] = linkUrl;
        }
      }
    }

    String? title;
    String? artist;
    String? artworkUrl;

    final entities = data['entitiesByUniqueId'] as Map<String, dynamic>?;
    if (entities != null && entities.isNotEmpty) {
      final firstEntity = entities.values.first as Map<String, dynamic>?;
      if (firstEntity != null) {
        title = firstEntity['title'] as String?;
        artist = firstEntity['artistName'] as String?;
        artworkUrl = firstEntity['thumbnailUrl'] as String?;
      }
    }

    return OdesliResult(
      title: title,
      artist: artist,
      artworkUrl: artworkUrl,
      directPlatformUrls: platformUrls,
    );
  }

  static OdesliResult? _parseWebPage(String html) {
    final match = RegExp(
      r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>',
      dotAll: true,
    ).firstMatch(html);

    if (match == null) return null;

    try {
      final jsonStr = match.group(1)!;
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final pageData = data['props']?['pageProps']?['pageData'] as Map<String, dynamic>?;
      if (pageData == null) return null;

      final entityData = pageData['entityData'] as Map<String, dynamic>?;
      final title = entityData?['title'] as String?;
      final artist = entityData?['artistName'] as String?;
      final artworkUrl = entityData?['thumbnailUrl'] as String?;

      final platformUrls = <PlatformType, String>{};
      final sections = pageData['sections'] as List<dynamic>? ?? [];

      for (final sec in sections) {
        if (sec is Map<String, dynamic>) {
          final links = sec['links'] as List<dynamic>? ?? [];
          for (final l in links) {
            if (l is Map<String, dynamic>) {
              final pName = l['platform'] as String?;
              final pUrl = l['url'] as String?;
              final platform = _platformMap[pName];
              if (platform != null && pUrl != null && pUrl.isNotEmpty) {
                platformUrls[platform] = pUrl;
              }
            }
          }
        }
      }

      return OdesliResult(
        title: title,
        artist: artist,
        artworkUrl: artworkUrl,
        directPlatformUrls: platformUrls,
      );
    } catch (e) {
      debugPrint('Error parsing Songlink NEXT_DATA: $e');
      return null;
    }
  }
}
