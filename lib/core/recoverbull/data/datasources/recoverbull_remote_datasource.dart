import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:recoverbull/recoverbull.dart';
import 'package:bull_tor/tor.dart';

/// Upper bound on one key-server reachability probe; the Tor session's own connect budget is shorter, so a Tor failure arrives with its reason first.
const keyServerProbeDeadline = Duration(seconds: 60);

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

  /// Throws [KeyServerProbeException], which keeps the transport reason that `KeyServer` reduces to a message.
  Future<void> checkConnection(TorProxyEndpoint endpoint) async {
    // Read before the probe: a local settings failure is not a server answer.
    final url = await _recoverbullSettingsDatasource.fetch();
    TorConnectFailure? connectFailure;
    final client = _torHttpClientFactory.create(
      endpoint,
      onConnectFailure: (failure) => connectFailure = failure,
    );
    try {
      await KeyServer(
        address: url,
        client: client,
      ).infos().timeout(keyServerProbeDeadline);
    } catch (e) {
      log.severe(
        message: 'checkConnection error',
        error: e,
        trace: StackTrace.current,
      );
      throw KeyServerProbeException(e, connectFailure);
    } finally {
      client.close(force: true);
    }
  }
}

/// A failed key-server probe, with the Tor connect reason when the failure happened before HTTP.
class KeyServerProbeException implements Exception {
  final Object error;
  final TorConnectFailure? connectFailure;

  const KeyServerProbeException(this.error, this.connectFailure);

  @override
  String toString() =>
      'KeyServerProbeException(${connectFailure?.name ?? 'no connect failure'}): $error';
}
