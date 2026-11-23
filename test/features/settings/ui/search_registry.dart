import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:settings/testing.dart';

/// Runs the same search as the hub over the app's current localized catalogue.
List<SettingsItem> searchRegistry(List<SettingsItem> items, String query) {
  final byId = {for (final item in items) item.id.name: item};
  return searchSettings(
    items.map((item) => item.hubEntry()),
    query,
  ).map((result) => byId[result.id]).nonNulls.toList();
}
