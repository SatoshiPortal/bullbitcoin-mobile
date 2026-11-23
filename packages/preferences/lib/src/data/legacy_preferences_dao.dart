import 'package:drift/drift.dart';

import '../../settings_table.dart';
import '../../dismissed_announcements_table.dart';
import '../../dismissed_announcements_table.drift.dart';
import 'preferences_dao.dart' show PreferencesMissingRowException;
import 'legacy_preferences_dao.drift.dart';

/// Borrows the tracked legacy connection. Never closes it or seeds its rows.
@DriftAccessor(tables: [Settings, DismissedAnnouncements])
class LegacyPreferencesDao extends DatabaseAccessor<GeneratedDatabase>
    with $LegacyPreferencesDaoMixin {
  LegacyPreferencesDao(super.attachedDatabase);

  Future<({String? username, String? password})> readCredentials() async {
    final query = selectOnly(settings)
      ..addColumns([
        settings.exchangeTestnetBasicAuthUsername,
        settings.exchangeTestnetBasicAuthPassword,
      ])
      ..where(settings.id.equals(1));
    final row = await query.getSingleOrNull();
    if (row == null) throw const PreferencesMissingRowException();
    return (
      username: row.read(settings.exchangeTestnetBasicAuthUsername),
      password: row.read(settings.exchangeTestnetBasicAuthPassword),
    );
  }

  Future<void> _requireUpdated(Future<int> pending) async {
    if (await pending != 1) throw const PreferencesMissingRowException();
  }

  Future<List<({String id, DateTime dismissedAt})>> readDismissals() async =>
      (await select(dismissedAnnouncements).get())
          .map((row) => (id: row.announcementId, dismissedAt: row.dismissedAt))
          .toList();

  Future<void> dismissAnnouncement(String id, DateTime dismissedAt) async {
    await into(dismissedAnnouncements).insertOnConflictUpdate(
      DismissedAnnouncementsCompanion.insert(
        announcementId: id,
        dismissedAt: dismissedAt,
      ),
    );
  }

  Future<void> setExchangeTestnetBasicAuth({
    String? username,
    String? password,
  }) async {
    await _requireUpdated(
      managers.settings
          .filter((row) => row.id(1))
          .update(
            (f) => f(
              exchangeTestnetBasicAuthUsername: Value(username),
              exchangeTestnetBasicAuthPassword: Value(password),
            ),
          ),
    );
  }
}
