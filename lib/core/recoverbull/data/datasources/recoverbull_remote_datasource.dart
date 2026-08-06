import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bb_mobile/core/tor/data/datasources/tor_datasource.dart';
import 'package:bb_mobile/core/tor/domain/value_objects/tor_proxy_config.dart';
import 'package:bb_mobile/core/tor/tor_status.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:recoverbull/recoverbull.dart';

export 'package:recoverbull/recoverbull.dart'
    show AttemptsResult, FetchBackupKeyResult, Info;

class RecoverBullRemoteDatasource {
  final RecoverbullSettingsDatasource _recoverbullSettingsDatasource;
  final TorDatasource _torDatasource;

  RecoverBullRemoteDatasource({
    required this._recoverbullSettingsDatasource,
    required this._torDatasource,
  });

  Future<void> info({TorProxyConfig? externalProxy}) async {
    final client = _torDatasource.httpClient(externalProxy: externalProxy);
    final url = await _recoverbullSettingsDatasource.fetch();
    try {
      final info = await KeyServer(address: url, client: client).infos();
      log.info('KeyServer canary: ${info.canary}');
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      rethrow;
    }
  }

  /// Returns the server info (canary-checked), including the telemetry
  /// metadata (`attempts_collection_started_at`, `max_attempt_identifiers`).
  Future<Info> infos({
    TorProxyConfig? externalProxy,
    String? expectedCanary,
  }) async {
    try {
      if (externalProxy == null) {
        await _waitForInternalTor();
      }
      final client = _torDatasource.httpClient(externalProxy: externalProxy);
      final url = await _recoverbullSettingsDatasource.fetch();
      return await KeyServer(
        address: url,
        client: client,
      ).infos(expectedCanary: expectedCanary);
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      rethrow;
    }
  }

  /// Conditional `GET /attempts`: the public brute-force telemetry snapshot.
  /// Only the entries matching [backupIds] or [backupIdHashes] are returned;
  /// the full snapshot never leaves the client's worker isolate.
  Future<AttemptsResult> attempts({
    String? etag,
    List<List<int>> backupIds = const [],
    List<String> backupIdHashes = const [],
    TorProxyConfig? externalProxy,
  }) async {
    try {
      if (externalProxy == null) {
        await _waitForInternalTor();
      }
      final client = _torDatasource.httpClient(externalProxy: externalProxy);
      final url = await _recoverbullSettingsDatasource.fetch();
      return await KeyServer(address: url, client: client).attempts(
        etag: etag,
        backupIds: backupIds,
        backupIdHashes: backupIdHashes,
      );
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      rethrow;
    }
  }

  /// Fetch with the exact attempt counters of the identifier's current
  /// rate-limit window — the freshest telemetry signal.
  Future<FetchBackupKeyResult> fetchWithStatus(
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
      ).fetchBackupKeyWithStatus(
        backupId: backupId,
        password: password,
        salt: salt,
      );
    } catch (e) {
      log.severe(
        message: 'fetchBackupKeyWithStatus error',
        error: e,
        trace: StackTrace.current,
      );
      rethrow;
    }
  }

  /// Trash with the exact attempt counters of the identifier's current
  /// rate-limit window.
  Future<FetchBackupKeyResult> trashWithStatus(
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
      ).trashBackupKeyWithStatus(
        backupId: backupId,
        password: password,
        salt: salt,
      );
    } catch (e) {
      log.severe(
        message: 'trashBackupKeyWithStatus error',
        error: e,
        trace: StackTrace.current,
      );
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
      log.severe(
        message: 'storeBackupKey error',
        error: e,
        trace: StackTrace.current,
      );
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
      log.severe(
        message: 'fetchBackupKey error',
        error: e,
        trace: StackTrace.current,
      );
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
      log.severe(
        message: 'trashBackupKey error',
        error: e,
        trace: StackTrace.current,
      );
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
      log.severe(
        message: 'checkConnection error',
        error: e,
        trace: StackTrace.current,
      );
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
