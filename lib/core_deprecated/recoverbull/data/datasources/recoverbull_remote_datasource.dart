import 'package:bb_mobile/core_deprecated/recoverbull/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bb_mobile/core_deprecated/tor/data/datasources/tor_datasource.dart';
import 'package:bb_mobile/core_deprecated/tor/domain/value_objects/tor_proxy_config.dart';
import 'package:bb_mobile/core_deprecated/tor/tor_status.dart';
import 'package:bb_mobile/core_deprecated/utils/logger.dart';
import 'package:recoverbull/recoverbull.dart';

class RecoverBullRemoteDatasource {
  final RecoverbullSettingsDatasource _recoverbullSettingsDatasource;
  final TorDatasource _torDatasource;

  RecoverBullRemoteDatasource({
    required RecoverbullSettingsDatasource recoverbullSettingsDatasource,
    required TorDatasource torDatasource,
  }) : _recoverbullSettingsDatasource = recoverbullSettingsDatasource,
       _torDatasource = torDatasource;

  Future<void> info({TorProxyConfig? externalProxy}) async {
    final client = _torDatasource.httpClient(externalProxy: externalProxy);
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
    List<int> backupKey, {
    TorProxyConfig? externalProxy,
  }) async {
    try {
      final client = _torDatasource.httpClient(externalProxy: externalProxy);
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
    List<int> salt, {
    TorProxyConfig? externalProxy,
  }) async {
    try {
      final client = _torDatasource.httpClient(externalProxy: externalProxy);
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
    List<int> salt, {
    TorProxyConfig? externalProxy,
  }) async {
    try {
      final client = _torDatasource.httpClient(externalProxy: externalProxy);
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

  Future<void> checkConnection({TorProxyConfig? externalProxy}) async {
    try {
      if (externalProxy == null) {
        await _waitForInternalTor();
      }

      final client = _torDatasource.httpClient(externalProxy: externalProxy);
      final url = await _recoverbullSettingsDatasource.fetch();
      await KeyServer(address: url, client: client).infos();
    } catch (e) {
      log.severe('checkConnection: $e');
      rethrow;
    }
  }

  Future<void> _waitForInternalTor() async {
    const maxWaitTime = Duration(minutes: 2);
    final startTime = DateTime.now();

    while (_torDatasource.status == TorStatus.connecting) {
      if (DateTime.now().difference(startTime) > maxWaitTime) {
        throw Exception('Timeout waiting for Tor to be ready');
      }
      log.info('Waiting for Tor to be ready...');
      await Future.delayed(const Duration(seconds: 3));
    }
  }
}
