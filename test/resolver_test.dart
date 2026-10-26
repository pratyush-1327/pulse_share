import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_share/core/models/platform_type.dart';
import 'package:pulse_share/core/models/track_info.dart';
import 'package:pulse_share/features/resolver/data/fast_url_parser.dart';
import 'package:pulse_share/features/resolver/data/itunes_api_source.dart';
import 'package:pulse_share/features/resolver/data/resolver_orchestrator.dart';

void main() {
  group('FastUrlParser Tests', () {
    test('Parses Spotify track URL correctly', () {
      final input = 'https://open.spotify.com/track/4cOdKLETKBW3PvgPWqT';
      final parsed = FastUrlParser.parse(input);

      expect(parsed.hasDirectUrl, isTrue);
      expect(parsed.platform, equals(PlatformType.spotify));
      expect(parsed.trackId, equals('4cOdKLETKBW3PvgPWqT'));
      expect(parsed.url, equals(input));
    });

    test('Parses Spotify URL embedded in chat text with trailing punctuation', () {
      final input = 'Bro listen to this https://open.spotify.com/track/4cOdKLETKBW3PvgPWqT?si=xyz123!';
      final parsed = FastUrlParser.parse(input);

      expect(parsed.hasDirectUrl, isTrue);
      expect(parsed.platform, equals(PlatformType.spotify));
      expect(parsed.trackId, equals('4cOdKLETKBW3PvgPWqT'));
      expect(parsed.url, equals('https://open.spotify.com/track/4cOdKLETKBW3PvgPWqT?si=xyz123'));
    });

    test('Parses Apple Music song URL correctly', () {
      final input = 'https://music.apple.com/us/album/blinding-lights/1499378108?i=1499378607';
      final parsed = FastUrlParser.parse(input);

      expect(parsed.hasDirectUrl, isTrue);
      expect(parsed.platform, equals(PlatformType.appleMusic));
      expect(parsed.trackId, equals('1499378607'));
    });

    test('Parses YouTube and YouTube Music URLs correctly', () {
      final ytInput = 'https://youtu.be/dQw4w9WgXcQ';
      final ytParsed = FastUrlParser.parse(ytInput);
      expect(ytParsed.platform, equals(PlatformType.youtube));
      expect(ytParsed.trackId, equals('dQw4w9WgXcQ'));

      final ytmInput = 'https://music.youtube.com/watch?v=dQw4w9WgXcQ';
      final ytmParsed = FastUrlParser.parse(ytmInput);
      expect(ytmParsed.platform, equals(PlatformType.youtubeMusic));
      expect(ytmParsed.trackId, equals('dQw4w9WgXcQ'));
    });

    test('Handles raw text query with no URL', () {
      final input = 'Blinding Lights by The Weeknd';
      final parsed = FastUrlParser.parse(input);

      expect(parsed.hasDirectUrl, isFalse);
      expect(parsed.url, isNull);
      expect(parsed.platform, isNull);
    });
  });

  group('Domain Model Serialization Tests', () {
    test('TrackInfo round-trips through JSON accurately', () {
      final original = TrackInfo(
        originalInput: 'https://open.spotify.com/track/123',
        title: 'Starboy',
        artist: 'The Weeknd',
        album: 'Starboy',
        artworkUrl: 'https://example.com/art.jpg',
        sourcePlatform: PlatformType.spotify,
        platformLinks: {
          PlatformType.spotify: const ResolvedLink(
            url: 'https://open.spotify.com/track/123',
            isDirect: true,
          ),
          PlatformType.appleMusic: const ResolvedLink(
            url: 'https://music.apple.com/song/456',
            isDirect: true,
          ),
          PlatformType.youtubeMusic: const ResolvedLink(
            url: 'https://music.youtube.com/search?q=Starboy',
            isDirect: false,
          ),
        },
      );

      final json = original.toJson();
      final restored = TrackInfo.fromJson(json);

      expect(restored.title, equals(original.title));
      expect(restored.artist, equals(original.artist));
      expect(restored.album, equals(original.album));
      expect(restored.artworkUrl, equals(original.artworkUrl));
      expect(restored.sourcePlatform, equals(PlatformType.spotify));
      expect(restored.platformLinks.length, equals(3));
      expect(restored.platformLinks[PlatformType.spotify]?.isDirect, isTrue);
      expect(restored.platformLinks[PlatformType.youtubeMusic]?.isDirect, isFalse);
    });

    test('Target platforms exclude SoundCloud, Tidal, and Deezer', () {
      expect(PlatformType.values, contains(PlatformType.spotify));
      expect(PlatformType.values, contains(PlatformType.appleMusic));
      expect(PlatformType.values, contains(PlatformType.youtubeMusic));
      expect(PlatformType.values, contains(PlatformType.youtube));
      expect(PlatformType.values, contains(PlatformType.amazonMusic));
      expect(PlatformType.values.length, equals(5));
    });
  });

  group('Network & Resolver Live Tests', () {
    test('ItunesApiSource returns rich metadata and 600x600 artwork', () async {
      final result = await ItunesApiSource.search('Blinding Lights The Weeknd');
      expect(result, isNotNull);
      expect(result!.title.toLowerCase(), contains('blinding lights'));
      expect(result.artist.toLowerCase(), contains('weeknd'));
      expect(result.artworkUrl, contains('600x600bb'));
      expect(result.appleMusicUrl, isNotNull);
    });

    test('ResolverOrchestrator resolves a known Spotify link with parallel race', () async {
      final spotifyUrl = 'https://open.spotify.com/track/0VjIjW4GlUZAMYd2vXMi3b'; // Blinding Lights
      final track = await ResolverOrchestrator.resolve(rawInput: spotifyUrl);

      expect(track.title, isNotEmpty);
      expect(track.artist, isNotEmpty);
      expect(track.platformLinks.containsKey(PlatformType.spotify), isTrue);
      expect(track.platformLinks.containsKey(PlatformType.appleMusic), isTrue);
      expect(track.platformLinks.containsKey(PlatformType.youtubeMusic), isTrue);
      expect(track.platformLinks.containsKey(PlatformType.youtube), isTrue);
      expect(track.platformLinks.containsKey(PlatformType.amazonMusic), isTrue);
    });
  });
}
