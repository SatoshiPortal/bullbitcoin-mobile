part of '../preferences.dart';

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
