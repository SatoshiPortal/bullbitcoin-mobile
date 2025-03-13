import 'package:bb_mobile/_core/data/datasources/tor_data_source.dart';
import 'package:recoverbull/recoverbull.dart';

abstract class RecoverBullRemoteDataSource {
  Future<void> info();

  Future<void> store(
    List<int> backupId,
    List<int> password,
    List<int> salt,
    List<int> backupKey,
  );

  Future<List<int>> fetch(
    List<int> backupId,
    List<int> password,
    List<int> salt,
  );

  Future<void> trash(
    List<int> backupId,
    List<int> password,
    List<int> salt,
  );
}

class RecoverBullRemoteDataSourceImpl implements RecoverBullRemoteDataSource {
  final KeyServer _keyServer;

  RecoverBullRemoteDataSourceImpl._(this._keyServer);

  static Future<RecoverBullRemoteDataSource> init(Uri address) async {
    final torDataSource = await TorDataSourceImpl.init();
    final tor = torDataSource.getTorClient();
    final keyServer = KeyServer(address: address);
    return RecoverBullRemoteDataSourceImpl._(keyServer);
  }

  @override
  Future<void> info() async {
    await _keyServer.infos();
  }

  @override
  Future<void> store(
    List<int> backupId,
    List<int> password,
    List<int> salt,
    List<int> backupKey,
  ) async {
    _keyServer.storeBackupKey(
      backupId: backupId,
      password: password,
      backupKey: backupKey,
      salt: salt,
    );
  }

  @override
  Future<List<int>> fetch(
    List<int> backupId,
    List<int> password,
    List<int> salt,
  ) async {
    return await _keyServer.fetchBackupKey(
      backupId: backupId,
      password: password,
      salt: salt,
    );
  }

  @override
  Future<void> trash(
    List<int> backupId,
    List<int> password,
    List<int> salt,
  ) async {
    await _keyServer.trashBackupKey(
      backupId: backupId,
      password: password,
      salt: salt,
    );
  }
}
