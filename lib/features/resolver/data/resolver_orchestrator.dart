import 'package:pulse_share/core/logging/app_logger.dart';
import 'package:pulse_share/core/models/platform_type.dart';
import 'package:pulse_share/core/models/track_info.dart';
import 'fast_url_parser.dart';
import 'cache_service.dart';
import 'odesli_api_source.dart';
import 'itunes_api_source.dart';
import 'youtube_api_source.dart';
import 'spotify_api_source.dart';
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
      talker.error('ResolverOrchestrator: Empty input provided');
      throw ArgumentError('Input text cannot be empty');
    }

    talker.info('🎵 ResolverOrchestrator: Starting resolution for "$cleanInput"');

    // 1. Check local cache (0ms instant return)
    final cached = await CacheService.getCachedTrack(cleanInput);
    if (cached != null) {
      talker.info('⚡ ResolverOrchestrator: Returning cached track "${cached.displayTitle}" (0ms)');
      return cached;
    }

    // 2. Parse URL and identify platform
    final parsed = FastUrlParser.parse(cleanInput);

    String? trackTitle;
    String? trackArtist;
    String? trackAlbum;
    String? artworkUrl;
    final directLinks = <PlatformType, String>{};

    // If we have a direct URL, record the source link immediately
    if (parsed.hasDirectUrl && parsed.url != null) {
      directLinks[parsed.platform!] = parsed.url!;
      talker.debug('ResolverOrchestrator: Preserved source direct link for ${parsed.platform?.displayName}');
    }

    if (parsed.url != null) {
      final stopwatch = Stopwatch()..start();

      // Step A: Fast First-Party Native Resolution (100-200ms)
      if ((parsed.platform == PlatformType.youtube || parsed.platform == PlatformType.youtubeMusic) &&
          parsed.trackId != null) {
        directLinks[PlatformType.youtubeMusic] = 'https://music.youtube.com/watch?v=${parsed.trackId}';
        directLinks[PlatformType.youtube] = 'https://youtu.be/${parsed.trackId}';

        final ytResult = await YoutubeApiSource.lookupByVideoId(parsed.trackId!);
        if (ytResult != null) {
          trackTitle = ytResult.title;
          trackArtist = ytResult.artist;
          artworkUrl = ytResult.artworkUrl;
        }
      } else if (parsed.platform == PlatformType.appleMusic && parsed.trackId != null) {
        final itunesResult = await ItunesApiSource.lookupById(parsed.trackId!);
        if (itunesResult != null) {
          trackTitle = itunesResult.title;
          trackArtist = itunesResult.artist;
          trackAlbum = itunesResult.album;
          artworkUrl = itunesResult.artworkUrl;
          if (itunesResult.appleMusicUrl != null) {
            directLinks[PlatformType.appleMusic] = itunesResult.appleMusicUrl!;
          }
        }
      } else if (parsed.platform == PlatformType.spotify && parsed.trackId != null) {
        final spotifyResult = await SpotifyApiSource.lookupByTrackId(parsed.trackId!);
        if (spotifyResult != null) {
          trackTitle = spotifyResult.title;
          trackArtist = spotifyResult.artist;
          artworkUrl = spotifyResult.artworkUrl;
        }
      }

      // Step B: Optional Odesli Aggregator Fallback (Only if metadata is missing or to discover other direct links)
      // Since Linktree deprecated the public Odesli API, we don't block the UI if we already have the track info
      if (trackTitle == null || trackArtist == null) {
        talker.debug('ResolverOrchestrator: Native source did not yield title/artist, querying Songlink fallback...');
        final odesliResult = await OdesliApiSource.fetchLinks(
          parsed.url!,
          platform: parsed.platform,
          trackId: parsed.trackId,
        );

        if (odesliResult != null) {
          trackTitle ??= odesliResult.title;
          trackArtist ??= odesliResult.artist;
          artworkUrl ??= odesliResult.artworkUrl;

          for (final entry in odesliResult.directPlatformUrls.entries) {
            directLinks.putIfAbsent(entry.key, () => entry.value);
          }
        }
      }

      stopwatch.stop();
      talker.debug('ResolverOrchestrator: Metadata resolution completed in ${stopwatch.elapsedMilliseconds}ms');

      // Step C: If we have trackTitle & trackArtist, query iTunes for Apple Music direct link & 600x600 artwork
      if (trackTitle != null && trackArtist != null) {
        if (!directLinks.containsKey(PlatformType.appleMusic) || artworkUrl == null || !artworkUrl.contains('600x600')) {
          final query = '$trackTitle $trackArtist';
          talker.debug('ResolverOrchestrator: Querying iTunes with verified title "$query"');
          final itunesSearch = await ItunesApiSource.search(query);
          if (itunesSearch != null) {
            artworkUrl = itunesSearch.artworkUrl ?? artworkUrl;
            trackAlbum ??= itunesSearch.album;
            if (itunesSearch.appleMusicUrl != null) {
              directLinks[PlatformType.appleMusic] = itunesSearch.appleMusicUrl!;
            }
          }
        }
      }
    }

    // 4. Fallback: If title or artist still missing (or text input without URL)
    if (trackTitle == null || trackArtist == null) {
      talker.warning('ResolverOrchestrator: Metadata still missing, attempting fallback...');

      // Try Gemini AI first if configured
      if (GeminiMusicService.hasKey(customGeminiKey)) {
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

      // CRITICAL GUARD: Only query iTunes with cleanInput if it is NOT a URL!
      final isUrl = cleanInput.startsWith('http://') || cleanInput.startsWith('https://');
      if (!isUrl && (trackTitle == null || trackArtist == null)) {
        talker.debug('ResolverOrchestrator: Querying iTunes with non-URL text: "$cleanInput"');
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

    talker.info(
      '🎉 ResolverOrchestrator: Resolution complete for "${resolvedTrack.displayTitle}"! '
      'Direct: ${finalPlatformLinks.values.where((l) => l.isDirect).length}/${finalPlatformLinks.length} platforms',
    );

    // 6. Cache for instant future retrieval
    await CacheService.saveTrack(cleanInput, resolvedTrack);

    return resolvedTrack;
  }
}
