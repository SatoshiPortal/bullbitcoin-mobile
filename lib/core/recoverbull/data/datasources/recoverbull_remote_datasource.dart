import 'package:bb_mobile/core/tor/data/datasources/tor_datasource.dart';
import 'package:bb_mobile/core/tor/tor_status.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:recoverbull/recoverbull.dart';

class RecoverBullRemoteDatasource {
  final Uri _address;
  final TorDatasource _torDatasource;

  RecoverBullRemoteDatasource(this._address, this._torDatasource);

  Future<void> info() async {
    final client = _torDatasource.httpClient;
    try {
      final info = await KeyServer(address: _address, client: client).infos();
      log.info('KeyServer canary: ${info.canary}');
    } catch (e) {
      log.severe('infos error: $e');
      rethrow;
    }
  }

  Future<void> store(
    List<int> backupId,
    List<int> password,
    List<int> salt,
    List<int> backupKey,
  ) async {
    try {
      final client = _torDatasource.httpClient;
      await KeyServer(address: _address, client: client).storeBackupKey(
        backupId: backupId,
        password: password,
        backupKey: backupKey,
        salt: salt,
      );
    } catch (e) {
      log.severe('storeBackupKey error: $e');
      rethrow;
    }
  }

  Future<List<int>> fetch(
    List<int> backupId,
    List<int> password,
    List<int> salt,
  ) async {
    try {
      final client = _torDatasource.httpClient;
      return await KeyServer(
        address: _address,
        client: client,
      ).fetchBackupKey(backupId: backupId, password: password, salt: salt);
    } catch (e) {
      log.severe('fetchBackupKey error: $e');
      rethrow;
    }
  }

  Future<void> trash(
    List<int> backupId,
    List<int> password,
    List<int> salt,
  ) async {
    try {
      final client = _torDatasource.httpClient;
      await KeyServer(
        address: _address,
        client: client,
      ).trashBackupKey(backupId: backupId, password: password, salt: salt);
    } catch (e) {
      log.severe('trashBackupKey error: $e');
      rethrow;
    }
  }

  Future<void> checkConnection() async {
    try {
      while (_torDatasource.status == TorStatus.connecting) {
        log.config('Waiting for Tor to be ready...');
        await Future.delayed(const Duration(seconds: 3));
      }

      final client = _torDatasource.httpClient;
      await KeyServer(address: _address, client: client).infos();
    } catch (e) {
      log.severe('checkConnection: $e');
      rethrow;
    }
  }
}
