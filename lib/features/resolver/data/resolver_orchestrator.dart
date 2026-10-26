import 'package:flutter/foundation.dart';
import 'package:pulse_share/core/models/platform_type.dart';
import 'package:pulse_share/core/models/track_info.dart';
import 'fast_url_parser.dart';
import 'cache_service.dart';
import 'odesli_api_source.dart';
import 'itunes_api_source.dart';
import 'gemini_music_service.dart';

class ResolverOrchestrator {
  static final List<PlatformType> _targetPlatforms = [
    PlatformType.spotify,
    PlatformType.appleMusic,
    PlatformType.youtubeMusic,
    PlatformType.youtube,
    PlatformType.amazonMusic,
  ];

  static Future<TrackInfo> resolve({
    required String rawInput,
    String? customGeminiKey,
  }) async {
    final cleanInput = rawInput.trim();
    if (cleanInput.isEmpty) {
      throw ArgumentError('Input text cannot be empty');
    }

    // 1. Check local cache (0ms instant return)
    final cached = await CacheService.getCachedTrack(cleanInput);
    if (cached != null) {
      debugPrint('ResolverOrchestrator: Cache hit for $cleanInput');
      return cached;
    }

    // 2. Parse URL and identify platform
    final parsed = FastUrlParser.parse(cleanInput);
    debugPrint('ResolverOrchestrator: Parsed URL=${parsed.url}, Platform=${parsed.platform?.displayName}');

    String? trackTitle;
    String? trackArtist;
    String? trackAlbum;
    String? artworkUrl;
    final directLinks = <PlatformType, String>{};

    // If we have a direct URL, record the source link immediately
    if (parsed.hasDirectUrl && parsed.url != null) {
      directLinks[parsed.platform!] = parsed.url!;
    }

    if (parsed.url != null) {
      // 3. Parallel Race: Query Odesli and Apple Music (iTunes) concurrently
      final futures = <Future<void>>[];

      // Odesli task
      OdesliResult? odesliResult;
      futures.add(() async {
        odesliResult = await OdesliApiSource.fetchLinks(parsed.url!);
      }());

      // Direct iTunes lookup task if it's an Apple Music URL
      ItunesApiResult? itunesResult;
      if (parsed.platform == PlatformType.appleMusic && parsed.trackId != null) {
        futures.add(() async {
          itunesResult = await ItunesApiSource.lookupById(parsed.trackId!);
        }());
      }

      await Future.wait(futures);

      // Merge Odesli results
      if (odesliResult != null) {
        trackTitle ??= odesliResult!.title;
        trackArtist ??= odesliResult!.artist;
        artworkUrl ??= odesliResult!.artworkUrl;

        for (final entry in odesliResult!.directPlatformUrls.entries) {
          if (!directLinks.containsKey(entry.key)) {
            directLinks[entry.key] = entry.value;
          }
        }
      }

      // Merge iTunes lookup results
      if (itunesResult != null) {
        trackTitle ??= itunesResult!.title;
        trackArtist ??= itunesResult!.artist;
        trackAlbum ??= itunesResult!.album;
        artworkUrl = itunesResult!.artworkUrl ?? artworkUrl;
        if (itunesResult!.appleMusicUrl != null) {
          directLinks[PlatformType.appleMusic] = itunesResult!.appleMusicUrl!;
        }
      }

      // If we got title & artist from Odesli, but no high-res iTunes artwork or Apple Music link, search iTunes
      if (trackTitle != null && trackArtist != null && (artworkUrl == null || !directLinks.containsKey(PlatformType.appleMusic))) {
        final query = '$trackTitle $trackArtist';
        final itunesSearch = await ItunesApiSource.search(query);
        if (itunesSearch != null) {
          artworkUrl = itunesSearch.artworkUrl ?? artworkUrl;
          trackAlbum ??= itunesSearch.album;
          if (itunesSearch.appleMusicUrl != null && !directLinks.containsKey(PlatformType.appleMusic)) {
            directLinks[PlatformType.appleMusic] = itunesSearch.appleMusicUrl!;
          }
        }
      }
    }

    // 4. If title or artist still missing (or text input without URL), invoke Gemini AI or iTunes Search
    if (trackTitle == null || trackArtist == null) {
      // Try Gemini AI first if configured
      if (GeminiMusicService.hasKey(customGeminiKey)) {
        debugPrint('ResolverOrchestrator: Invoking Gemini for input: $cleanInput');
        final geminiResult = await GeminiMusicService.parseAndResolve(
          rawInput: cleanInput,
          customApiKey: customGeminiKey,
        );

        if (geminiResult != null) {
          trackTitle = geminiResult.title;
          trackArtist = geminiResult.artist;
          trackAlbum = geminiResult.album;
          for (final entry in geminiResult.directLinks.entries) {
            directLinks.putIfAbsent(entry.key, () => entry.value);
          }
        }
      }

      // If still missing, query iTunes with cleanInput
      if (trackTitle == null || trackArtist == null) {
        final itunesSearch = await ItunesApiSource.search(cleanInput);
        if (itunesSearch != null) {
          trackTitle = itunesSearch.title;
          trackArtist = itunesSearch.artist;
          trackAlbum = itunesSearch.album;
          artworkUrl = itunesSearch.artworkUrl;
          if (itunesSearch.appleMusicUrl != null) {
            directLinks[PlatformType.appleMusic] = itunesSearch.appleMusicUrl!;
          }
        }
      }
    }

    // Final fallback for title/artist if completely unrecognized
    final finalTitle = trackTitle ?? 'Shared Song';
    final finalArtist = trackArtist ?? 'Unknown Artist';
    final queryForSearch = '$finalTitle $finalArtist'.trim();

    // 5. Build final map with Direct Links + Smart Search Fallbacks
    final finalPlatformLinks = <PlatformType, ResolvedLink>{};
    for (final platform in _targetPlatforms) {
      if (directLinks.containsKey(platform) && directLinks[platform]!.isNotEmpty) {
        finalPlatformLinks[platform] = ResolvedLink(
          url: directLinks[platform]!,
          isDirect: true,
        );
      } else {
        finalPlatformLinks[platform] = ResolvedLink(
          url: platform.generateSearchUrl(queryForSearch),
          isDirect: false,
        );
      }
    }

    final resolvedTrack = TrackInfo(
      originalInput: cleanInput,
      title: finalTitle,
      artist: finalArtist,
      album: trackAlbum,
      artworkUrl: artworkUrl,
      sourcePlatform: parsed.platform,
      platformLinks: finalPlatformLinks,
    );

    // 6. Cache for instant future retrieval
    await CacheService.saveTrack(cleanInput, resolvedTrack);

    return resolvedTrack;
  }
}
