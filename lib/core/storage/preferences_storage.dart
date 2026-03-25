import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesStorage {
  static const _keyDeviceId = 'device_id';
  static const _keyAnonymousUserId = 'anonymous_user_id';
  static const _keyColumnOffset = 'column_offset';
  static const _keyImagePadding = 'image_padding';
  static const _keyNsfwFilter = 'nsfw_filter';
  static const _keyThemeMode = 'theme_mode';
  static const _keyColumnCount = 'column_count';
  static const _keyAccentColor = 'accent_color';
  static const _keySearchHistory = 'search_history';

  static late SharedPreferences _prefs;
  static SharedPreferences get prefs => _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Device ID - persistent across app restarts
  static String getDeviceId() {
    String? deviceId = _prefs.getString(_keyDeviceId);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = _generateRandomId(16);
      _prefs.setString(_keyDeviceId, deviceId);
    }
    return deviceId;
  }

  // Anonymous user ID
  static String getAnonymousUserId() {
    String? userId = _prefs.getString(_keyAnonymousUserId);
    if (userId == null || userId.isEmpty) {
      userId = 'anonymous@@${_generateRandomId(16)}';
      _prefs.setString(_keyAnonymousUserId, userId);
    }
    return userId;
  }

  // Settings
  static int getColumnOffset() => _prefs.getInt(_keyColumnOffset) ?? 0;
  static Future<void> setColumnOffset(int value) =>
      _prefs.setInt(_keyColumnOffset, value);

  static int getImagePadding() => _prefs.getInt(_keyImagePadding) ?? 2;
  static Future<void> setImagePadding(int value) =>
      _prefs.setInt(_keyImagePadding, value);

  static bool getNsfwFilter() => _prefs.getBool(_keyNsfwFilter) ?? true;
  static Future<void> setNsfwFilter(bool value) =>
      _prefs.setBool(_keyNsfwFilter, value);

  static String getThemeMode() => _prefs.getString(_keyThemeMode) ?? 'system';
  static Future<void> setThemeMode(String value) =>
      _prefs.setString(_keyThemeMode, value);

  static int getColumnCount() => _prefs.getInt(_keyColumnCount) ?? 2;
  static Future<void> setColumnCount(int value) =>
      _prefs.setInt(_keyColumnCount, value);

  // Accent color (stored as hex int, 0 means default)
  static int getAccentColor() => _prefs.getInt(_keyAccentColor) ?? 0;
  static Future<void> setAccentColor(int value) =>
      _prefs.setInt(_keyAccentColor, value);

  // Search history
  static List<String> getSearchHistory() =>
      _prefs.getStringList(_keySearchHistory) ?? const [];
  static Future<void> setSearchHistory(List<String> history) =>
      _prefs.setStringList(_keySearchHistory, history);

  static String _generateRandomId(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }
}
