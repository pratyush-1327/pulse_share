import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_share/core/models/platform_type.dart';

class PreferencesService extends ChangeNotifier {
  static const String _keyPreferredPlatform = 'pref_preferred_platform';
  static const String _keyGeminiApiKey = 'pref_gemini_api_key';
  static const String _keyAutoOpen = 'pref_auto_open_preferred';

  PlatformType _preferredPlatform = PlatformType.spotify;
  String? _geminiApiKey;
  bool _autoOpen = false;
  bool _isInitialized = false;

  PlatformType get preferredPlatform => _preferredPlatform;
  String? get geminiApiKey => _geminiApiKey;
  bool get autoOpen => _autoOpen;
  bool get isInitialized => _isInitialized;

  PreferencesService() {
    init();
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPlatformId = prefs.getString(_keyPreferredPlatform);
      if (savedPlatformId != null) {
        final platform = PlatformTypeExtension.fromId(savedPlatformId);
        if (platform != null) _preferredPlatform = platform;
      }

      _geminiApiKey = prefs.getString(_keyGeminiApiKey);
      _autoOpen = prefs.getBool(_keyAutoOpen) ?? false;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('PreferencesService init error: $e');
    }
  }

  Future<void> setPreferredPlatform(PlatformType platform) async {
    _preferredPlatform = platform;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPreferredPlatform, platform.id);
  }

  Future<void> setGeminiApiKey(String? key) async {
    final clean = key?.trim();
    _geminiApiKey = clean == null || clean.isEmpty ? null : clean;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (_geminiApiKey != null) {
      await prefs.setString(_keyGeminiApiKey, _geminiApiKey!);
    } else {
      await prefs.remove(_keyGeminiApiKey);
    }
  }

  Future<void> setAutoOpen(bool enabled) async {
    _autoOpen = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoOpen, enabled);
  }
}
