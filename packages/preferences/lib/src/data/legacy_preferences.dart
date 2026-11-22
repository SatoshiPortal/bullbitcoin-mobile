part of '../preferences.dart';

typedef DismissedAnnouncement = ({String id, DateTime dismissedAt});
typedef RecoverBullServerPreference = ({Uri server, bool permissionGranted});

final class AnnouncementDismissals {
  final PreferencesDao _dao;
  const AnnouncementDismissals._(this._dao);

  @useResult
  Future<Result<List<DismissedAnnouncement>, PreferencesFailure>> read() async {
    try {
      return Ok(await _dao.readDismissals());
    } on Exception catch (error) {
      return Err(PreferencesReadFailure(error.runtimeType.toString()));
    }
  }

  @useResult
  Future<Result<void, PreferencesFailure>> dismiss(
    String id,
    DateTime dismissedAt,
  ) async {
    try {
      await _dao.dismissAnnouncement(id, dismissedAt);
      return const Ok(null);
    } on Exception catch (error) {
      return Err(PreferencesWriteFailure(error.runtimeType.toString()));
    }
  }
}

final class RecoverBullPreferences {
  final PreferencesDao _dao;
  const RecoverBullPreferences._(this._dao);

  @useResult
  Future<Result<RecoverBullServerPreference?, PreferencesFailure>>
  read() async {
    try {
      final row = await _dao.readRecoverBull();
      if (row == null) return const Ok(null);
      return Ok((
        server: Uri.parse(row.url),
        permissionGranted: row.permissionGranted,
      ));
    } on FormatException {
      return const Err(PreferencesInvalidFailure());
    } on Exception catch (error) {
      return Err(PreferencesReadFailure(error.runtimeType.toString()));
    }
  }
}
