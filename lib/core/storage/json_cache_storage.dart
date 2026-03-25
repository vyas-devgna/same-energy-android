import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class JsonCacheStorage {
  JsonCacheStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _prefix = 'json_cache_v1::';
  static const _tsSuffix = '::ts';

  Map<String, dynamic>? read(String key, {Duration? maxAge}) {
    final cacheKey = '$_prefix$key';
    final raw = _prefs.getString(cacheKey);
    if (raw == null || raw.isEmpty) return null;

    if (maxAge != null) {
      final ts = _prefs.getInt('$cacheKey$_tsSuffix');
      if (ts == null) return null;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > maxAge.inMilliseconds) return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  Future<void> write(String key, Map<String, dynamic> value) async {
    final cacheKey = '$_prefix$key';
    await _prefs.setString(cacheKey, jsonEncode(value));
    await _prefs.setInt(
      cacheKey + _tsSuffix,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> remove(String key) async {
    final cacheKey = '$_prefix$key';
    await _prefs.remove(cacheKey);
    await _prefs.remove(cacheKey + _tsSuffix);
  }
}
