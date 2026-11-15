import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings owns the adapter between local app preferences and the UI feature.
final class SettingsQuickActionsStorage implements QuickActionsStorage {
  @override
  Future<String?> read(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.get(key);
    if (value == null || value is String) return value as String?;
    throw const FormatException('Invalid quick actions preference type');
  }

  @override
  Future<void> write(String key, String value) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(key, value)) {
      throw const FormatException('Quick actions preference was not saved');
    }
  }

  @override
  Future<void> remove(String key) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.remove(key)) {
      throw const FormatException('Quick actions preference was not removed');
    }
  }
}
