import '../../preferences_dao.dart';

typedef DismissedAnnouncement = ({String id, DateTime dismissedAt});
typedef RecoverBullServerPreference = ({Uri server, bool permissionGranted});

final class AnnouncementDismissals {
  final PreferencesDao _dao;

  const AnnouncementDismissals(this._dao);

  Future<List<DismissedAnnouncement>> read() => _dao.readDismissals();

  Future<void> dismiss(String id, DateTime dismissedAt) =>
      _dao.dismissAnnouncement(id, dismissedAt);
}

final class RecoverBullPreferences {
  final PreferencesDao _dao;

  const RecoverBullPreferences(this._dao);

  Future<RecoverBullServerPreference?> read() async {
    final row = await _dao.readRecoverBull();
    if (row == null) return null;
    return (
      server: Uri.parse(row.url),
      permissionGranted: row.permissionGranted,
    );
  }
}
