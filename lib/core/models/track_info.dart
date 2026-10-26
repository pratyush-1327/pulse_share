import 'platform_type.dart';

class ResolvedLink {
  final String url;
  final bool isDirect;

  const ResolvedLink({
    required this.url,
    required this.isDirect,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'isDirect': isDirect,
      };

  factory ResolvedLink.fromJson(Map<String, dynamic> json) => ResolvedLink(
        url: json['url'] as String,
        isDirect: json['isDirect'] as bool? ?? false,
      );
}

class TrackInfo {
  final String originalInput;
  final String title;
  final String artist;
  final String? album;
  final String? artworkUrl;
  final String? isrc;
  final PlatformType? sourcePlatform;
  final Map<PlatformType, ResolvedLink> platformLinks;

  const TrackInfo({
    required this.originalInput,
    required this.title,
    required this.artist,
    this.album,
    this.artworkUrl,
    this.isrc,
    this.sourcePlatform,
    required this.platformLinks,
  });

  String get displayTitle => '$title • $artist';

  ResolvedLink? linkFor(PlatformType platform) => platformLinks[platform];

  TrackInfo copyWith({
    String? originalInput,
    String? title,
    String? artist,
    String? album,
    String? artworkUrl,
    String? isrc,
    PlatformType? sourcePlatform,
    Map<PlatformType, ResolvedLink>? platformLinks,
  }) {
    return TrackInfo(
      originalInput: originalInput ?? this.originalInput,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      isrc: isrc ?? this.isrc,
      sourcePlatform: sourcePlatform ?? this.sourcePlatform,
      platformLinks: platformLinks ?? this.platformLinks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'originalInput': originalInput,
      'title': title,
      'artist': artist,
      'album': album,
      'artworkUrl': artworkUrl,
      'isrc': isrc,
      'sourcePlatform': sourcePlatform?.id,
      'platformLinks': platformLinks.map(
        (key, value) => MapEntry(key.id, value.toJson()),
      ),
    };
  }

  factory TrackInfo.fromJson(Map<String, dynamic> json) {
    final linksMap = <PlatformType, ResolvedLink>{};
    final rawLinks = json['platformLinks'] as Map<String, dynamic>? ?? {};
    rawLinks.forEach((key, val) {
      final platform = PlatformTypeExtension.fromId(key);
      if (platform != null && val is Map<String, dynamic>) {
        linksMap[platform] = ResolvedLink.fromJson(val);
      }
    });

    final sourceId = json['sourcePlatform'] as String?;
    return TrackInfo(
      originalInput: json['originalInput'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown Title',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      album: json['album'] as String?,
      artworkUrl: json['artworkUrl'] as String?,
      isrc: json['isrc'] as String?,
      sourcePlatform: sourceId != null ? PlatformTypeExtension.fromId(sourceId) : null,
      platformLinks: linksMap,
    );
  }
}
