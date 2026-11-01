import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pulse_share/core/logging/app_logger.dart';

class SpotifyApiResult {
  final String title;
  final String? artist;
  final String? artworkUrl;

  const SpotifyApiResult({
    required this.title,
    this.artist,
    this.artworkUrl,
  });
}

class SpotifyApiSource {
  static final http.Client _client = http.Client();

  static Future<SpotifyApiResult?> lookupByTrackId(String trackId) async {
    try {
      final uri = Uri.parse('https://open.spotify.com/oembed').replace(
        queryParameters: {
          'url': 'https://open.spotify.com/track/$trackId',
        },
      );

      talker.debug('SpotifyApiSource: Looking up Spotify track ID "$trackId"');

      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) {
        talker.warning('SpotifyApiSource: oEmbed returned HTTP ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final title = (data['title'] as String?)?.trim();
      final artworkUrl = data['thumbnail_url'] as String?;

      if (title == null || title.isEmpty) return null;

      talker.info('SpotifyApiSource: Resolved title "$title"');

      return SpotifyApiResult(
        title: title,
        artworkUrl: artworkUrl,
      );
    } catch (e, stack) {
      talker.handle(e, stack, 'SpotifyApiSource error');
      return null;
    }
  }
}
