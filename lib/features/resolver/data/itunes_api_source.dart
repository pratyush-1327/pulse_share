import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pulse_share/core/logging/app_logger.dart';

class ItunesApiResult {
  final String title;
  final String artist;
  final String? album;
  final String? artworkUrl;
  final String? appleMusicUrl;
  final String? previewAudioUrl;

  const ItunesApiResult({
    required this.title,
    required this.artist,
    this.album,
    this.artworkUrl,
    this.appleMusicUrl,
    this.previewAudioUrl,
  });
}

class ItunesApiSource {
  static final http.Client _client = http.Client();

  static Future<ItunesApiResult?> search(String query) async {
    try {
      if (query.trim().isEmpty) return null;

      final uri = Uri.parse('https://itunes.apple.com/search').replace(
        queryParameters: {
          'term': query,
          'entity': 'song',
          'limit': '5',
        },
      );

      talker.debug('ItunesApiSource: Searching "$query"');

      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) {
        talker.warning('ItunesApiSource: Search returned HTTP ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        talker.debug('ItunesApiSource: No songs found for "$query"');
        return null;
      }

      // Select top result
      final top = results[0] as Map<String, dynamic>;
      final trackName = top['trackName'] as String?;
      final artistName = top['artistName'] as String?;
      if (trackName == null || artistName == null) return null;

      final collectionName = top['collectionName'] as String?;
      final trackViewUrl = top['trackViewUrl'] as String?;
      final rawArtwork = top['artworkUrl100'] as String?;
      final previewUrl = top['previewUrl'] as String?;

      // Upgrade artwork to 600x600 resolution
      final artworkUrl = rawArtwork?.replaceAll('100x100bb', '600x600bb');

      // Clean apple music URL (strip tracking params like &uo=4)
      String? cleanAppleUrl;
      if (trackViewUrl != null) {
        final parsed = Uri.parse(trackViewUrl);
        cleanAppleUrl = Uri(
          scheme: parsed.scheme,
          host: parsed.host,
          path: parsed.path,
          queryParameters: parsed.queryParameters.containsKey('i')
              ? {'i': parsed.queryParameters['i']!}
              : null,
        ).toString();
      }

      talker.info('ItunesApiSource: Found "$trackName" by "$artistName" (Artwork 600x600 ready)');

      return ItunesApiResult(
        title: trackName,
        artist: artistName,
        album: collectionName,
        artworkUrl: artworkUrl,
        appleMusicUrl: cleanAppleUrl ?? trackViewUrl,
        previewAudioUrl: previewUrl,
      );
    } catch (e, stack) {
      talker.handle(e, stack, 'ItunesApiSource search error');
      return null;
    }
  }

  /// Lookup Apple Music song by track ID
  static Future<ItunesApiResult?> lookupById(String trackId) async {
    try {
      final uri = Uri.parse('https://itunes.apple.com/lookup').replace(
        queryParameters: {
          'id': trackId,
          'entity': 'song',
        },
      );

      talker.debug('ItunesApiSource: Looking up track ID $trackId');

      final response = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) {
        talker.warning('ItunesApiSource: Lookup returned HTTP ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final top = results[0] as Map<String, dynamic>;
      final trackName = top['trackName'] as String?;
      final artistName = top['artistName'] as String?;
      if (trackName == null || artistName == null) return null;

      final rawArtwork = top['artworkUrl100'] as String?;
      final artworkUrl = rawArtwork?.replaceAll('100x100bb', '600x600bb');

      talker.info('ItunesApiSource: ID lookup resolved "$trackName" by "$artistName"');

      return ItunesApiResult(
        title: trackName,
        artist: artistName,
        album: top['collectionName'] as String?,
        artworkUrl: artworkUrl,
        appleMusicUrl: top['trackViewUrl'] as String?,
        previewAudioUrl: top['previewUrl'] as String?,
      );
    } catch (e, stack) {
      talker.handle(e, stack, 'ItunesApiSource lookupById error');
      return null;
    }
  }
}
