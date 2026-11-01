import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pulse_share/core/logging/app_logger.dart';

class YoutubeApiResult {
  final String title;
  final String artist;
  final String? artworkUrl;

  const YoutubeApiResult({
    required this.title,
    required this.artist,
    this.artworkUrl,
  });
}

class YoutubeApiSource {
  static final http.Client _client = http.Client();

  static Future<YoutubeApiResult?> lookupByVideoId(String videoId) async {
    try {
      final uri = Uri.parse('https://www.youtube.com/oembed').replace(
        queryParameters: {
          'url': 'https://www.youtube.com/watch?v=$videoId',
          'format': 'json',
        },
      );

      talker.debug('YoutubeApiSource: Looking up YouTube video ID "$videoId"');

      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) {
        talker.warning('YoutubeApiSource: oEmbed returned HTTP ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawTitle = (data['title'] as String?)?.trim() ?? '';
      final rawAuthor = (data['author_name'] as String?)?.trim() ?? '';
      final thumbnailUrl = data['thumbnail_url'] as String?;

      if (rawTitle.isEmpty) return null;

      String songTitle = rawTitle;
      String artistName = rawAuthor;

      // 1. YouTube Music Topic channel format: "Artist - Topic"
      if (artistName.toLowerCase().endsWith(' - topic')) {
        artistName = artistName.replaceAll(RegExp(r'\s*-\s*topic$', caseSensitive: false), '').trim();
      }
      // 2. Video title format: "Artist - Title" or "Artist - Title (Official Video)"
      else if (songTitle.contains(' - ')) {
        final parts = songTitle.split(' - ');
        artistName = parts[0].trim();
        songTitle = parts.sublist(1).join(' - ').trim();
      }

      // Clean common video noise from title
      songTitle = _cleanTitle(songTitle);

      talker.info('YoutubeApiSource: Resolved "$songTitle" by "$artistName"');

      return YoutubeApiResult(
        title: songTitle,
        artist: artistName,
        artworkUrl: thumbnailUrl,
      );
    } catch (e, stack) {
      talker.handle(e, stack, 'YoutubeApiSource error');
      return null;
    }
  }

  static String _cleanTitle(String title) {
    return title
        .replaceAll(
          RegExp(
            r'\s*[\(\[](?:official\s*(?:video|audio|music\s*video|lyric\s*video)?|lyrics?|visualizer|4k|hd|audio)[\)\]]',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }
}
