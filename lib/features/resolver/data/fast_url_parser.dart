import 'package:pulse_share/core/models/platform_type.dart';

class ParsedInput {
  final String rawInput;
  final String? url;
  final PlatformType? platform;
  final String? trackId;

  const ParsedInput({
    required this.rawInput,
    this.url,
    this.platform,
    this.trackId,
  });

  bool get hasDirectUrl => url != null && platform != null;
}

class FastUrlParser {
  static final RegExp _urlRegex = RegExp(r'(https?:\/\/[^\s]+)');

  static final Map<PlatformType, List<RegExp>> _patterns = {
    PlatformType.spotify: [
      RegExp(r'open\.spotify\.com/track/([a-zA-Z0-9]+)'),
      RegExp(r'spotify:track:([a-zA-Z0-9]+)'),
    ],
    PlatformType.appleMusic: [
      RegExp(r'music\.apple\.com/[\w-]+/song/(\d+)'),
      RegExp(r'music\.apple\.com/[\w-]+/album/[^/]+/(\d+)\?i=(\d+)'),
      RegExp(r'music\.apple\.com/[\w-]+/album/(\d+)\?i=(\d+)'),
      RegExp(r'music\.apple\.com/[\w-]+/album/[^/]+/(\d+)'),
    ],
    PlatformType.youtubeMusic: [
      RegExp(r'music\.youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})'),
    ],
    PlatformType.youtube: [
      RegExp(r'(?:youtube\.com/watch\?v=|youtu\.be/)([a-zA-Z0-9_-]{11})'),
    ],
    PlatformType.amazonMusic: [
      RegExp(r'music\.amazon\.com/[\w-]+/[\w-]+/([a-zA-Z0-9]+)'),
      RegExp(r'amazon\.com/[\w-]+/dp/([a-zA-Z0-9]+)'),
    ],
  };

  static ParsedInput parse(String raw) {
    final cleanInput = raw.trim();
    final urlMatch = _urlRegex.firstMatch(cleanInput);

    if (urlMatch == null) {
      return ParsedInput(rawInput: cleanInput);
    }

    String foundUrl = urlMatch.group(1)!;
    // Strip trailing punctuation often appended by chat apps
    foundUrl = foundUrl.replaceAll(RegExp(r'[.,;!?)>]+$'), '');

    PlatformType? detectedPlatform;
    String? extractedId;

    for (final entry in _patterns.entries) {
      for (final pattern in entry.value) {
        final match = pattern.firstMatch(foundUrl);
        if (match != null) {
          detectedPlatform = entry.key;
          extractedId = match.group(match.groupCount);
          break;
        }
      }
      if (detectedPlatform != null) break;
    }

    // Specific Apple Music override: ?i=TRACK_ID is the song ID
    if (detectedPlatform == PlatformType.appleMusic) {
      try {
        final uri = Uri.parse(foundUrl);
        if (uri.queryParameters.containsKey('i')) {
          extractedId = uri.queryParameters['i'];
        }
      } catch (_) {}
    }

    return ParsedInput(
      rawInput: cleanInput,
      url: foundUrl,
      platform: detectedPlatform,
      trackId: extractedId,
    );
  }
}
