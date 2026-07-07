import 'package:flutter/foundation.dart';
import 'package:music_share/core/constants/music_services.dart';
import '../models/music_link.dart';

class LinkParser {
  static final List<_ServiceConfig> _configs = [
    _ServiceConfig(
      service: MusicServices.spotify,
      idPatterns: [
        RegExp(r'open\.spotify\.com/track/([a-zA-Z0-9]+)'),
        RegExp(r'spotify:track:([a-zA-Z0-9]+)'),
      ],
    ),
    _ServiceConfig(
      service: MusicServices.appleMusic,
      idPatterns: [
        RegExp(r'music\.apple\.com/[\w-]+/song/(\d+)'),
        RegExp(r'music\.apple\.com/[\w-]+/album/[\w-]+/(\d+)'),
      ],
    ),
    _ServiceConfig(
      service: MusicServices.youtubeMusic,
      idPatterns: [
        RegExp(r'music\.youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})'),
        RegExp(r'music\.youtube\.com/playlist\?list=([a-zA-Z0-9_-]+)'),
      ],
    ),
    _ServiceConfig(
      service: MusicServices.youtube,
      idPatterns: [
        RegExp(r'(?:youtube\.com/watch\?v=|youtu\.be/)([a-zA-Z0-9_-]{11})'),
        RegExp(r'youtube\.com/playlist\?list=([a-zA-Z0-9_-]+)'),
      ],
    ),
    _ServiceConfig(
      service: MusicServices.soundCloud,
      idPatterns: [
        RegExp(r'soundcloud\.com/[\w-]+/[\w-]+'),
        RegExp(r'on\.soundcloud\.com/[\w-]+/[\w-]+'),
      ],
    ),
    _ServiceConfig(
      service: MusicServices.deezer,
      idPatterns: [
        RegExp(r'deezer\.com/track/(\d+)'),
        RegExp(r'deezer\.com/[\w-]+/track/(\d+)'),
      ],
    ),
    _ServiceConfig(
      service: MusicServices.amazonMusic,
      idPatterns: [
        RegExp(r'music\.amazon\.com/[\w-]+/[\w-]+/(\w+)'),
        RegExp(r'amazon\.com/[\w-]+/dp/(\w+)'),
      ],
    ),
    _ServiceConfig(
      service: MusicServices.tidal,
      idPatterns: [
        RegExp(r'tidal\.com/track/(\d+)'),
        RegExp(r'tidal\.com/browse/track/(\d+)'),
      ],
    ),
  ];

  static MusicLink parse(String url, {String? trackName, String? artistName}) {
    debugPrint('LinkParser.parse: URL=$url, trackName=$trackName, artistName=$artistName');

    String? extractedId;
    MusicService? detectedService;
    for (final config in _configs) {
      for (final pattern in config.idPatterns) {
        final match = pattern.firstMatch(url);
        if (match != null) {
          extractedId = match.group(1);
          detectedService = config.service;
          debugPrint('LinkParser: Detected service=${detectedService.name}, ID=$extractedId');
          break;
        }
      }
      if (detectedService != null) break;
    }

    if (detectedService == null) {
      debugPrint('LinkParser: No service detected for URL: $url');
    }

    // If no service detected, try to extract title from URL
    if (trackName == null && detectedService == null) {
      trackName = _extractTitleFromUrl(url);
      debugPrint('LinkParser: Extracted title from URL: $trackName');
    }

    final availableLinks = _generateAvailableLinks(
      originalUrl: url,
      sourceService: detectedService,
      trackId: extractedId,
      trackName: trackName,
      artistName: artistName,
    );

    debugPrint('LinkParser: Generated ${availableLinks.length} available links');

    return MusicLink(
      originalUrl: url,
      sourceService: detectedService,
      trackId: extractedId,
      trackName: trackName,
      artistName: artistName,
      availableLinks: availableLinks,
    );
  }

  static List<ServiceLink> _generateAvailableLinks({
    required String originalUrl,
    required MusicService? sourceService,
    required String? trackId,
    required String? trackName,
    required String? artistName,
  }) {
    final availableLinks = <ServiceLink>[];

    // Build query for search links
    String searchQuery = 'music';
    if (trackName != null && artistName != null) {
      searchQuery = '$trackName $artistName';
    } else if (trackName != null) {
      searchQuery = trackName;
    } else if (originalUrl.isNotEmpty) {
      searchQuery = _extractTitleFromUrl(originalUrl) ?? 'music';
    }
    final encodedQuery = Uri.encodeComponent(searchQuery);

    // 1. Spotify
    String spotifyUrl;
    if (sourceService?.id == 'spotify' && trackId != null) {
      spotifyUrl = 'https://open.spotify.com/track/$trackId';
    } else {
      spotifyUrl = 'https://open.spotify.com/search/$encodedQuery';
    }
    availableLinks.add(ServiceLink(service: MusicServices.spotify, url: spotifyUrl));

    // 2. Apple Music
    String appleMusicUrl;
    if (sourceService?.id == 'apple_music' && trackId != null) {
      appleMusicUrl = 'https://music.apple.com/song/$trackId';
    } else {
      appleMusicUrl = 'https://music.apple.com/search?term=$encodedQuery';
    }
    availableLinks.add(ServiceLink(service: MusicServices.appleMusic, url: appleMusicUrl));

    // 3. YouTube Music
    String youtubeMusicUrl;
    if ((sourceService?.id == 'youtube_music' || sourceService?.id == 'youtube') && trackId != null) {
      youtubeMusicUrl = 'https://music.youtube.com/watch?v=$trackId';
    } else {
      youtubeMusicUrl = 'https://music.youtube.com/search?q=$encodedQuery';
    }
    availableLinks.add(ServiceLink(service: MusicServices.youtubeMusic, url: youtubeMusicUrl));

    // 4. YouTube
    String youtubeUrl;
    if ((sourceService?.id == 'youtube_music' || sourceService?.id == 'youtube') && trackId != null) {
      youtubeUrl = 'https://youtu.be/$trackId';
    } else {
      youtubeUrl = 'https://www.youtube.com/results?search_query=$encodedQuery';
    }
    availableLinks.add(ServiceLink(service: MusicServices.youtube, url: youtubeUrl));

    // 5. SoundCloud
    String soundCloudUrl;
    if (sourceService?.id == 'soundcloud' && trackId != null) {
      soundCloudUrl = 'https://soundcloud.com/search?q=$encodedQuery';
    } else {
      soundCloudUrl = 'https://soundcloud.com/search?q=$encodedQuery';
    }
    availableLinks.add(ServiceLink(service: MusicServices.soundCloud, url: soundCloudUrl));

    // 6. Deezer
    String deezerUrl;
    if (sourceService?.id == 'deezer' && trackId != null) {
      deezerUrl = 'https://www.deezer.com/track/$trackId';
    } else {
      deezerUrl = 'https://www.deezer.com/search/$encodedQuery';
    }
    availableLinks.add(ServiceLink(service: MusicServices.deezer, url: deezerUrl));

    // 7. Amazon Music
    String amazonMusicUrl;
    if (sourceService?.id == 'amazon_music' && trackId != null) {
      amazonMusicUrl = 'https://music.amazon.com/search/$encodedQuery';
    } else {
      amazonMusicUrl = 'https://music.amazon.com/search/$encodedQuery';
    }
    availableLinks.add(ServiceLink(service: MusicServices.amazonMusic, url: amazonMusicUrl));

    // 8. Tidal
    String tidalUrl;
    if (sourceService?.id == 'tidal' && trackId != null) {
      tidalUrl = 'https://listen.tidal.com/track/$trackId';
    } else {
      tidalUrl = 'https://listen.tidal.com/search?q=$encodedQuery';
    }
    availableLinks.add(ServiceLink(service: MusicServices.tidal, url: tidalUrl));

    return availableLinks;
  }

  static String? _extractTitleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments
          .where((s) => s.isNotEmpty && !RegExp(r'^\d+$').hasMatch(s))
          .toList();
      if (pathSegments.isNotEmpty) {
        final title = pathSegments.last
            .replaceAll('-', ' ')
            .replaceAll('_', ' ')
            .replaceAll(RegExp(r'\.[^.]+$'), '');
        return title.split(' ').map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        }).join(' ');
      }
    } catch (_) {}
    return null;
  }
}

class _ServiceConfig {
  final MusicService service;
  final List<RegExp> idPatterns;

  const _ServiceConfig({
    required this.service,
    required this.idPatterns,
  });
}