import 'package:shared_preferences/shared_preferences.dart';

/// Whether swaps use the trusted (Bull exchange order) path. Persisted outside
/// the database like the swap server setting. Default false = trustless (Boltz).
class SwapModeSettingRepository {
  static const _key = 'swaps.trusted.enabled';

  Future<bool> isTrustedEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setTrustedEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}
