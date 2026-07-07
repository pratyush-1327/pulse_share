import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PlatformResolver {
  /// Maps our service IDs to their direct link patterns
  static const Map<String, String> _serviceUrlPrefixes = {
    'spotify': 'https://open.spotify.com/track/',
    'apple_music': 'https://music.apple.com/song/',
    'youtube_music': 'https://music.youtube.com/watch?v=',
    'youtube': 'https://youtu.be/',
    'soundcloud': 'https://soundcloud.com/',
    'deezer': 'https://www.deezer.com/track/',
    'amazon_music': 'https://music.amazon.com/albums/',
    'tidal': 'https://listen.tidal.com/track/',
  };

  /// Try to find a direct link for a given platform using song info
  static Future<String?> resolvePlatform(
    String serviceId,
    String? trackName,
    String? artistName,
  ) async {
    if (trackName == null && artistName == null) return null;

    final query = [artistName, trackName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');

    switch (serviceId) {
      case 'deezer':
        return _searchDeezer(query);
      case 'apple_music':
        return _searchAppleMusic(query);
      case 'soundcloud':
        return _searchSoundCloud(query);
      case 'spotify':
        return _searchSpotify(query);
      case 'tidal':
        return _searchTidal(query);
      case 'amazon_music':
        return _searchAmazonMusic(query);
      default:
        return null;
    }
  }

  /// Deezer: Public API, no auth needed
  static Future<String?> _searchDeezer(String query) async {
    try {
      final uri = Uri.parse('https://api.deezer.com/search')
          .replace(queryParameters: {'q': query, 'limit': '1', 'order': 'RANKING'});
      debugPrint('DeezerAPI: Searching $uri');
      final response = await http.get(uri, headers: {'User-Agent': 'MusicShare/1.0'});
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tracks = data['data'] as List<dynamic>?;
      if (tracks == null || tracks.isEmpty) return null;

      final first = tracks[0] as Map<String, dynamic>;
      final id = first['id'];
      final title = first['title'] as String?;
      final artist = first['artist'] is Map ? (first['artist'] as Map)['name'] : null;

      // Verify it's a good match by checking title similarity
      if (title != null) {
        final queryWords = query.toLowerCase().split(' ');
        final titleWords = (title as String).toLowerCase().split(' ');
        final overlap = queryWords.where((w) => titleWords.contains(w)).length;
        if (overlap < 1) {
          debugPrint('DeezerAPI: Skipping "$title" — poor match for "$query"');
          return null;
        }
      }

      final link = 'https://www.deezer.com/track/$id';
      debugPrint('DeezerAPI: Found track $id ($title - $artist) -> $link');
      return link;
    } catch (e) {
      debugPrint('DeezerAPI error: $e');
      return null;
    }
  }

  /// Apple Music via iTunes Search API (free, no auth)
  static Future<String?> _searchAppleMusic(String query) async {
    try {
      final uri = Uri.parse('https://itunes.apple.com/search')
          .replace(queryParameters: {
        'term': query,
        'entity': 'song',
        'limit': '5',
        'country': 'IN',
      });
      debugPrint('AppleMusicAPI: Searching $uri');
      final response = await http.get(uri, headers: {'User-Agent': 'MusicShare/1.0'});
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      // Find the best match by comparing artist name
      final queryArtist = query.contains(' ')
          ? query.substring(0, query.lastIndexOf(' ')).toLowerCase()
          : '';

      Map<String, dynamic>? bestMatch;
      for (final r in results) {
        final result = r as Map<String, dynamic>;
        final artistName = (result['artistName'] as String? ?? '').toLowerCase();
        if (queryArtist.isNotEmpty && artistName.contains(queryArtist)) {
          bestMatch = result;
          break;
        }
      }
      bestMatch ??= results[0] as Map<String, dynamic>;

      final trackId = bestMatch['trackId'];
      final collectionId = bestMatch['collectionId'] ?? '';
      final trackName = bestMatch['trackName'] as String? ?? '';

      // Use the proper Apple Music song URL format
      String link;
      if (collectionId.toString().isNotEmpty) {
        link = 'https://music.apple.com/in/album/$collectionId?i=$trackId';
      } else {
        link = 'https://music.apple.com/in/song/$trackId';
      }
      debugPrint('AppleMusicAPI: Found track $trackId ($trackName) -> $link');
      return link;
    } catch (e) {
      debugPrint('AppleMusicAPI error: $e');
      return null;
    }
  }

  /// Spotify: Use search page + embedded JSON-LD or Next.js data
  static Future<String?> _searchSpotify(String query) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final uri = Uri.parse('https://open.spotify.com/search/$encoded');
      debugPrint('SpotifyScrape: Fetching $uri');
      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
        'Accept': 'text/html',
      });
      if (response.statusCode != 200) return null;

      final html = response.body;

      // Search for track URIs in all JavaScript/text content
      final uriMatches = RegExp(r'spotify:track:([a-zA-Z0-9]+)').allMatches(html);
      if (uriMatches.isNotEmpty) {
        final ids = uriMatches.map((m) => m.group(1)).toSet().toList();
        if (ids.isNotEmpty) {
          final link = 'https://open.spotify.com/track/${ids[0]}';
          debugPrint('SpotifyScrape: Found track URIs, using first -> $link');
          return link;
        }
      }

      // Try JSON-LD
      final jsonLdMatch = RegExp(
        r'<script[^>]+type="application/ld\+json"[^>]*>(.*?)</script>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(html);
      if (jsonLdMatch != null) {
        try {
          final jsonLd = jsonDecode(jsonLdMatch.group(1)!) as Map<String, dynamic>;
          final url = jsonLd['url'] as String?;
          if (url != null && url.contains('open.spotify.com/track/')) {
            debugPrint('SpotifyScrape: Found via JSON-LD -> $url');
            return url;
          }
        } catch (_) {}
      }

      // Try Next.js data
      final nextMatch = RegExp(
        r'<script[^>]+id="__NEXT_DATA__"[^>]*>(.*?)</script>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(html);
      if (nextMatch != null) {
        try {
          final nextData = jsonDecode(nextMatch.group(1)!) as Map<String, dynamic>;
          final jsonStr = jsonEncode(nextData);
          final trackMatch = RegExp(r'"uri"\s*:\s*"spotify:track:([a-zA-Z0-9]+)"').firstMatch(jsonStr);
          if (trackMatch != null) {
            final link = 'https://open.spotify.com/track/${trackMatch.group(1)}';
            debugPrint('SpotifyScrape: Found via Next.js data -> $link');
            return link;
          }
        } catch (_) {}
      }

      // Try Open Graph tags
      final ogMatch = RegExp(
        r'<meta[^>]+property="og:url"[^>]+content="([^"]+)"',
        caseSensitive: false,
      ).firstMatch(html);
      if (ogMatch != null) {
        final ogUrl = ogMatch.group(1)!;
        if (ogUrl.contains('open.spotify.com/track/')) {
          debugPrint('SpotifyScrape: Found via OG -> $ogUrl');
          return ogUrl;
        }
      }

      debugPrint('SpotifyScrape: No track found in page');
      return null;
    } catch (e) {
      debugPrint('SpotifyScrape error: $e');
      return null;
    }
  }

  /// SoundCloud: Scrape search page for first track URL (excluding /search/)
  static Future<String?> _searchSoundCloud(String query) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final uri = Uri.parse('https://soundcloud.com/search/sounds?q=$encoded');
      debugPrint('SoundCloudScrape: Fetching $uri');
      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
        'Accept': 'text/html',
      });
      if (response.statusCode != 200) return null;

      final html = response.body;

      // Find track URLs that are NOT search pages
      final trackMatch = RegExp(
        r'https://soundcloud\.com/(?!search/)([a-zA-Z0-9_-]+)/([a-zA-Z0-9_-]+)',
      ).firstMatch(html);

      if (trackMatch != null) {
        final link = trackMatch.group(0)!;
        // Remove trailing garbage
        final cleanLink = link.replaceAll(RegExp(r'[^a-zA-Z0-9_\-/:.]'), '');
        debugPrint('SoundCloudScrape: Found track -> $cleanLink');
        return cleanLink;
      }

      return null;
    } catch (e) {
      debugPrint('SoundCloudScrape error: $e');
      return null;
    }
  }

  /// Tidal: Scrape search page for first track URL
  static Future<String?> _searchTidal(String query) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final uri = Uri.parse('https://listen.tidal.com/search/tracks?q=$encoded');
      debugPrint('TidalScrape: Fetching $uri');
      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
        'Accept': 'text/html',
      });
      if (response.statusCode != 200) return null;

      final html = response.body;
      final trackMatch = RegExp(
        r'https://listen\.tidal\.com/track/\d+',
      ).firstMatch(html);

      if (trackMatch != null) {
        final link = trackMatch.group(0)!;
        debugPrint('TidalScrape: Found track -> $link');
        return link;
      }

      return null;
    } catch (e) {
      debugPrint('TidalScrape error: $e');
      return null;
    }
  }

  /// Amazon Music: Try to find track from search page
  static Future<String?> _searchAmazonMusic(String query) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final uri = Uri.parse('https://music.amazon.com/search/$encoded');
      debugPrint('AmazonMusicScrape: Fetching $uri');
      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
        'Accept': 'text/html',
      });
      if (response.statusCode != 200) return null;

      final html = response.body;
      final trackMatch = RegExp(
        r'https://music\.amazon\.com/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+/[a-zA-Z0-9]+',
      ).firstMatch(html);

      if (trackMatch != null) {
        final link = trackMatch.group(0)!;
        debugPrint('AmazonMusicScrape: Found track -> $link');
        return link;
      }

      return null;
    } catch (e) {
      debugPrint('AmazonMusicScrape error: $e');
      return null;
    }
  }
}