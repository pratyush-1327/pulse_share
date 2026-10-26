import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_share/core/models/track_info.dart';

class CacheService {
  static const String _trackCachePrefix = 'cache_track_';
  static const String _recentTracksKey = 'recent_tracks_list';
  static const int _maxRecents = 20;

  static String _normalizeKey(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static Future<TrackInfo?> getCachedTrack(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_trackCachePrefix${_normalizeKey(key)}';
      final jsonString = prefs.getString(cacheKey);
      if (jsonString == null) return null;

      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      return TrackInfo.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveTrack(String key, TrackInfo track) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(track.toJson());

      // 1. Save direct key
      final cacheKey = '$_trackCachePrefix${_normalizeKey(key)}';
      await prefs.setString(cacheKey, jsonString);

      // 2. Also cache by song display title for query match
      final titleKey = '$_trackCachePrefix${_normalizeKey(track.displayTitle)}';
      await prefs.setString(titleKey, jsonString);

      // 3. Add to recents
      await _addToRecents(prefs, jsonString);
    } catch (_) {}
  }

  static Future<void> _addToRecents(SharedPreferences prefs, String jsonString) async {
    final list = prefs.getStringList(_recentTracksKey) ?? [];
    // Deduplicate by parsing title
    list.removeWhere((item) {
      try {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        final current = jsonDecode(jsonString) as Map<String, dynamic>;
        return decoded['title'] == current['title'] && decoded['artist'] == current['artist'];
      } catch (_) {
        return false;
      }
    });

    list.insert(0, jsonString);
    if (list.length > _maxRecents) {
      list.removeRange(_maxRecents, list.length);
    }
    await prefs.setStringList(_recentTracksKey, list);
  }

  static Future<List<TrackInfo>> getRecentTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_recentTracksKey) ?? [];
      final result = <TrackInfo>[];
      for (final item in list) {
        try {
          final decoded = jsonDecode(item) as Map<String, dynamic>;
          result.add(TrackInfo.fromJson(decoded));
        } catch (_) {}
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_trackCachePrefix) || k == _recentTracksKey);
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
