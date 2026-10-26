import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:pulse_share/core/models/platform_type.dart';

class GeminiParsedSong {
  final String title;
  final String artist;
  final String? album;
  final Map<PlatformType, String> directLinks;

  const GeminiParsedSong({
    required this.title,
    required this.artist,
    this.album,
    this.directLinks = const {},
  });
}

class GeminiMusicService {
  static const String _defaultApiKey = String.fromEnvironment('GEMINI_API_KEY');

  static bool hasKey(String? customKey) {
    final key = (customKey != null && customKey.trim().isNotEmpty) ? customKey : _defaultApiKey;
    return key.trim().isNotEmpty;
  }

  /// Parses messy input text, YouTube video titles, or captions into clean track and artist
  static Future<GeminiParsedSong?> parseAndResolve({
    required String rawInput,
    String? customApiKey,
  }) async {
    final apiKey = (customApiKey != null && customApiKey.trim().isNotEmpty)
        ? customApiKey.trim()
        : _defaultApiKey.trim();

    if (apiKey.isEmpty) {
      debugPrint('GeminiMusicService: No API key provided');
      return null;
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.1,
        ),
      );

      final prompt = '''
Analyze this music share input: "$rawInput".
Identify the canonical song title and primary artist name. Remove noise such as "Official Video", "Lyrics", "4K", audio tags, remix tags unless part of title.
Also, if you know the verified URLs or search identifiers for Spotify, Apple Music, and YouTube Music, include them.

Respond ONLY with valid JSON in this exact structure:
{
  "title": "Exact Song Name",
  "artist": "Primary Artist Name",
  "album": "Album Name or null",
  "links": {
    "spotify": "direct open.spotify.com/track/... url or null",
    "apple_music": "direct music.apple.com url or null",
    "youtube_music": "direct music.youtube.com url or null",
    "youtube": "direct youtube.com/watch url or null"
  }
}
''';

      final response = await model.generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 5));

      final text = response.text;
      if (text == null || text.trim().isEmpty) return null;

      final data = jsonDecode(text) as Map<String, dynamic>;
      final title = data['title'] as String?;
      final artist = data['artist'] as String?;

      if (title == null || title.isEmpty || artist == null || artist.isEmpty) {
        return null;
      }

      final linksMap = <PlatformType, String>{};
      final rawLinks = data['links'] as Map<String, dynamic>? ?? {};
      rawLinks.forEach((k, v) {
        if (v is String && v.startsWith('http')) {
          final platform = PlatformTypeExtension.fromId(k);
          if (platform != null) {
            linksMap[platform] = v;
          }
        }
      });

      return GeminiParsedSong(
        title: title,
        artist: artist,
        album: data['album'] as String?,
        directLinks: linksMap,
      );
    } catch (e) {
      debugPrint('GeminiMusicService error: $e');
      return null;
    }
  }
}
