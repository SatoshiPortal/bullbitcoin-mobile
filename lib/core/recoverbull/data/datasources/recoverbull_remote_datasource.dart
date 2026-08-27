import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:recoverbull/recoverbull.dart';
import 'package:bull_tor/tor.dart';

class RecoverBullRemoteDatasource {
  final RecoverbullSettingsDatasource _recoverbullSettingsDatasource;
  final TorHttpClientFactory _torHttpClientFactory;

  RecoverBullRemoteDatasource({
    required this._recoverbullSettingsDatasource,
    required this._torHttpClientFactory,
  });

  Future<void> info(TorProxyEndpoint endpoint) async {
    final client = _torHttpClientFactory.create(endpoint);
    final url = await _recoverbullSettingsDatasource.fetch();
    try {
      final info = await KeyServer(address: url, client: client).infos();
      log.info('KeyServer canary: ${info.canary}');
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> store(
    List<int> backupId,
    List<int> password,
    List<int> salt,
    List<int> backupKey, {
    required TorProxyEndpoint endpoint,
  }) async {
    final client = _torHttpClientFactory.create(endpoint);
    try {
      final url = await _recoverbullSettingsDatasource.fetch();
      await KeyServer(address: url, client: client).storeBackupKey(
        backupId: backupId,
        password: password,
        backupKey: backupKey,
        salt: salt,
      );
    } catch (e) {
      log.severe(
        message: 'storeBackupKey error',
        error: e,
        trace: StackTrace.current,
      );
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<List<int>> fetch(
    List<int> backupId,
    List<int> password,
    List<int> salt, {
    required TorProxyEndpoint endpoint,
  }) async {
    final client = _torHttpClientFactory.create(endpoint);
    try {
      final url = await _recoverbullSettingsDatasource.fetch();
      return await KeyServer(
        address: url,
        client: client,
      ).fetchBackupKey(backupId: backupId, password: password, salt: salt);
    } catch (e) {
      log.severe(
        message: 'fetchBackupKey error',
        error: e,
        trace: StackTrace.current,
      );
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> trash(
    List<int> backupId,
    List<int> password,
    List<int> salt, {
    required TorProxyEndpoint endpoint,
  }) async {
    final client = _torHttpClientFactory.create(endpoint);
    try {
      final url = await _recoverbullSettingsDatasource.fetch();
      await KeyServer(
        address: url,
        client: client,
      ).trashBackupKey(backupId: backupId, password: password, salt: salt);
    } catch (e) {
      log.severe(
        message: 'trashBackupKey error',
        error: e,
        trace: StackTrace.current,
      );
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> checkConnection(TorProxyEndpoint endpoint) async {
    final client = _torHttpClientFactory.create(endpoint);
    try {
      final url = await _recoverbullSettingsDatasource.fetch();
      await KeyServer(address: url, client: client).infos();
    } catch (e) {
      log.severe(
        message: 'checkConnection error',
        error: e,
        trace: StackTrace.current,
      );
      rethrow;
    } finally {
      client.close(force: true);
    }
  }
}
