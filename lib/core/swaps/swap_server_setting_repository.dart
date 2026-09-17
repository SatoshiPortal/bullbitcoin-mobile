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

  /// Empty input is valid (falls back to the default). Anything else must
  /// normalize to a parseable host — permissive on purpose so IP:port,
  /// localhost and .onion backends all pass.
  static bool isValid(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return true;
    if (trimmed.contains(RegExp(r'\s'))) return false;
    final normalized = trimmed
        .replaceFirst(RegExp('^(https?|wss?)://'), '')
        .replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse('https://$normalized');
    return uri != null && uri.host.isNotEmpty;
  }

  /// True when the stored value opts into plaintext (explicit http://).
  static bool isPlaintext(String url) => url.startsWith('http://');

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// The engine expects a bare host path and prefixes https:// and wss://
  /// itself. One deliberate exception: an explicitly typed `http://` is kept
  /// (and the websocket follows it as ws://) so a local dev/staging backend
  /// through an SSH tunnel works — the production default can never be
  /// downgraded because it carries no scheme.
  String _normalize(String url) {
    final trimmed = url.replaceFirst(RegExp(r'/+$'), '');
    if (trimmed.startsWith('http://')) return trimmed;
    return trimmed.replaceFirst(RegExp('^(https|wss?)://'), '');
  }
}
