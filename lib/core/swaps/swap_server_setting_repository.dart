import 'package:shared_preferences/shared_preferences.dart';

/// The user-configurable Boltz backend, persisted outside the database (no
/// schema impact). The engine reads it once at startup — changing the server
/// takes effect on the next app launch.
class SwapServerSettingRepository {
  static const _key = 'swaps.boltz.url';
  static const defaultUrl = 'api.boltz.exchange/v2';

  Future<String> fetch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key)?.trim();
      if (stored == null || stored.isEmpty) return defaultUrl;
      return _normalize(stored);
    } catch (_) {
      return defaultUrl;
    }
  }

  Future<void> save(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_key);
      return;
    }
    await prefs.setString(_key, _normalize(trimmed));
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// The engine expects a bare host path (it prefixes https:// itself).
  String _normalize(String url) => url
      .replaceFirst(RegExp('^https?://'), '')
      .replaceFirst(RegExp(r'/+$'), '');
}
