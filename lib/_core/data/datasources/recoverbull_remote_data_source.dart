import 'package:recoverbull/recoverbull.dart';

abstract class RecoverBullRemoteDataSource {
  Future<void> info(SOCKSSocket? socks);

  Future<void> store(
    SOCKSSocket? socks,
    List<int> backupId,
    List<int> password,
    List<int> salt,
    List<int> backupKey,
  );

  Future<List<int>> fetch(
    SOCKSSocket? socks,
    List<int> backupId,
    List<int> password,
    List<int> salt,
  );

  Future<void> trash(
    SOCKSSocket? socks,
    List<int> backupId,
    List<int> password,
    List<int> salt,
  );
}

class RecoverBullRemoteDataSourceImpl implements RecoverBullRemoteDataSource {
  final KeyServer _keyServer;

  RecoverBullRemoteDataSourceImpl._(this._keyServer);

  @override
  Future<void> info(SOCKSSocket? socks) async {
    await _keyServer.infos(socks: socks);
  }

  @override
  Future<void> store(
    SOCKSSocket? socks,
    List<int> backupId,
    List<int> password,
    List<int> salt,
    List<int> backupKey,
  ) async {
    _keyServer.storeBackupKey(
      socks: socks,
      backupId: backupId,
      password: password,
      backupKey: backupKey,
      salt: salt,
    );
  }

  @override
  Future<List<int>> fetch(
    SOCKSSocket? socks,
    List<int> backupId,
    List<int> password,
    List<int> salt,
  ) async {
    return await _keyServer.fetchBackupKey(
      socks: socks,
      backupId: backupId,
      password: password,
      salt: salt,
    );
  }

  @override
  Future<void> trash(
    SOCKSSocket? socks,
    List<int> backupId,
    List<int> password,
    List<int> salt,
  ) async {
    await _keyServer.trashBackupKey(
      socks: socks,
      backupId: backupId,
      password: password,
      salt: salt,
    );
  }
}
