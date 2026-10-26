import 'package:flutter/material.dart';

enum PlatformType {
  spotify,
  appleMusic,
  youtubeMusic,
  youtube,
  amazonMusic,
}

extension PlatformTypeExtension on PlatformType {
  String get id {
    switch (this) {
      case PlatformType.spotify:
        return 'spotify';
      case PlatformType.appleMusic:
        return 'apple_music';
      case PlatformType.youtubeMusic:
        return 'youtube_music';
      case PlatformType.youtube:
        return 'youtube';
      case PlatformType.amazonMusic:
        return 'amazon_music';
    }
  }

  String get displayName {
    switch (this) {
      case PlatformType.spotify:
        return 'Spotify';
      case PlatformType.appleMusic:
        return 'Apple Music';
      case PlatformType.youtubeMusic:
        return 'YouTube Music';
      case PlatformType.youtube:
        return 'YouTube';
      case PlatformType.amazonMusic:
        return 'Amazon Music';
    }
  }

  Color get brandColor {
    switch (this) {
      case PlatformType.spotify:
        return const Color(0xFF1DB954);
      case PlatformType.appleMusic:
        return const Color(0xFFFC3C44);
      case PlatformType.youtubeMusic:
        return const Color(0xFFFF0000);
      case PlatformType.youtube:
        return const Color(0xFFFF0000);
      case PlatformType.amazonMusic:
        return const Color(0xFF00A8E1);
    }
  }

  IconData get icon {
    switch (this) {
      case PlatformType.spotify:
        return Icons.graphic_eq_rounded;
      case PlatformType.appleMusic:
        return Icons.apple_rounded;
      case PlatformType.youtubeMusic:
        return Icons.play_circle_fill_rounded;
      case PlatformType.youtube:
        return Icons.smart_display_rounded;
      case PlatformType.amazonMusic:
        return Icons.album_rounded;
    }
  }

  String generateSearchUrl(String query) {
    final encoded = Uri.encodeComponent(query);
    switch (this) {
      case PlatformType.spotify:
        return 'https://open.spotify.com/search/$encoded';
      case PlatformType.appleMusic:
        return 'https://music.apple.com/search?term=$encoded';
      case PlatformType.youtubeMusic:
        return 'https://music.youtube.com/search?q=$encoded';
      case PlatformType.youtube:
        return 'https://www.youtube.com/results?search_query=$encoded';
      case PlatformType.amazonMusic:
        return 'https://music.amazon.com/search/$encoded';
    }
  }

  static PlatformType? fromId(String id) {
    switch (id.toLowerCase()) {
      case 'spotify':
        return PlatformType.spotify;
      case 'apple_music':
      case 'applemusic':
      case 'apple':
      case 'itunes':
        return PlatformType.appleMusic;
      case 'youtube_music':
      case 'youtubemusic':
        return PlatformType.youtubeMusic;
      case 'youtube':
        return PlatformType.youtube;
      case 'amazon_music':
      case 'amazonmusic':
      case 'amazon':
        return PlatformType.amazonMusic;
      default:
        return null;
    }
  }
}
