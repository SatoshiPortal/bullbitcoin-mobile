import 'package:shared_preferences/shared_preferences.dart';

import '../domain/quick_actions_repository.dart';

/// Persists the layout using the existing quick-actions preference key.
final class SharedPreferencesQuickActionsStorage
    implements QuickActionsStorage {
  const SharedPreferencesQuickActionsStorage();

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
