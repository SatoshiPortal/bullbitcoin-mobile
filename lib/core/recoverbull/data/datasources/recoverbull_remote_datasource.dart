import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bb_mobile/core/tor/data/datasources/tor_datasource.dart';
import 'package:bb_mobile/core/tor/tor_status.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:recoverbull/recoverbull.dart';

class RecoverBullRemoteDatasource {
  final RecoverbullSettingsDatasource _recoverbullSettingsDatasource;
  final TorDatasource _torDatasource;

  RecoverBullRemoteDatasource({
    required RecoverbullSettingsDatasource recoverbullSettingsDatasource,
    required TorDatasource torDatasource,
  }) : _recoverbullSettingsDatasource = recoverbullSettingsDatasource,
       _torDatasource = torDatasource;

  Future<void> info() async {
    final client = _torDatasource.httpClient;
    final url = await _recoverbullSettingsDatasource.fetch();
    try {
      final info = await KeyServer(address: url, client: client).infos();
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
      final url = await _recoverbullSettingsDatasource.fetch();
      await KeyServer(address: url, client: client).storeBackupKey(
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
      final url = await _recoverbullSettingsDatasource.fetch();
      return await KeyServer(
        address: url,
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
      final url = await _recoverbullSettingsDatasource.fetch();
      await KeyServer(
        address: url,
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
      final url = await _recoverbullSettingsDatasource.fetch();
      await KeyServer(address: url, client: client).infos();
    } catch (e) {
      log.severe('checkConnection: $e');
      rethrow;
    }
  }
}
