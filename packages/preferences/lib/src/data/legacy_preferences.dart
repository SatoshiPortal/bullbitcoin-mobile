part of '../preferences.dart';

typedef DismissedAnnouncement = ({String id, DateTime dismissedAt});

final class AnnouncementDismissals {
  final LegacyPreferencesDao _dao;
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
  Future<Result<bool?, PreferencesFailure>> read({bool regtest = false}) async {
    return (await readState(regtest: regtest)).map((value) => value?.granted);
  }

  @useResult
  Future<Result<({bool granted, int revision})?, PreferencesFailure>>
  readState({bool regtest = false}) async {
    try {
      return Ok(await _dao.readRecoverBullPermission(regtest: regtest));
    } on Exception catch (error) {
      return Err(PreferencesReadFailure(error.runtimeType.toString()));
    }
  }

  @useResult
  Future<Result<void, PreferencesFailure>> setPermission(
    bool permission, {
    bool regtest = false,
  }) async {
    try {
      await _dao.setRecoverBullPermission(permission, regtest: regtest);
      return const Ok(null);
    } on Exception catch (error) {
      return Err(PreferencesWriteFailure(error.runtimeType.toString()));
    }
  }
}
