import 'dart:async';
import 'dart:io';

import './recoverbull_settings_datasource.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:recoverbull/recoverbull.dart';
import 'package:convert/convert.dart' as convert;
import '../../attempt_monitoring/recoverbull_attempt_monitoring.dart';
import '../../domain/recoverbull_server_url.dart';
import '../../domain/recoverbull_tor_route.dart';
import '../../public/recoverbull.dart' show RecoverBullTiming;

class RecoverBullRemoteDatasource {
  final LogSink log;
  final RecoverbullSettingsDatasource _recoverbullSettingsDatasource;
  final Future<void> Function(Uri, HttpClient)? infoRequest;
  final Future<FetchBackupKeyResult> Function(
    Uri,
    HttpClient,
    List<int>,
    List<int>,
    List<int>,
  )?
  fetchRequest;
  final Future<void> Function(
    Uri,
    HttpClient,
    List<int>,
    List<int>,
    List<int>,
    List<int>,
  )?
  storeRequest;
  final Future<FetchBackupKeyResult> Function(
    Uri,
    HttpClient,
    List<int>,
    List<int>,
    List<int>,
  )?
  trashRequest;
  final Future<AttemptsResult> Function(Uri, HttpClient, String?, List<String>)?
  attemptsRequest;
  final RecoverBullTiming? timing;
  final Duration operationTimeout;
  final Duration healthCheckTimeout;

  RecoverBullRemoteDatasource({
    required this._recoverbullSettingsDatasource,
    required this.log,
    this.timing,
    this.infoRequest,
    this.fetchRequest,
    this.storeRequest,
    this.trashRequest,
    this.attemptsRequest,
    this.operationTimeout = const Duration(seconds: 20),
    this.healthCheckTimeout = const Duration(seconds: 30),
  });

  Future<T> _timed<T>(
    String phase,
    Future<T> Function() operation, {
    Duration? timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final value = await operation().timeout(timeout ?? operationTimeout);
      timing?.call(phase, stopwatch.elapsedMilliseconds, 'success');
      return value;
    } on TimeoutException {
      timing?.call(phase, stopwatch.elapsedMilliseconds, 'timeout');
      rethrow;
    } catch (_) {
      timing?.call(phase, stopwatch.elapsedMilliseconds, 'failure');
      rethrow;
    }
  }

  Future<void> info(RecoverBullTorRoute route) async {
    try {
      final url = validateRecoverBullServerUrl(
        await _recoverbullSettingsDatasource.fetch(),
      );
      if (infoRequest case final request?) {
        await _timed('server_info', () => request(url, route.client));
      } else {
        await _timed(
          'server_info',
          () => KeyServer(address: url, client: route.client).infos(),
        );
      }
    } catch (e) {
      log.error(
        'recoverbull.info.unexpected error_type=${e.runtimeType}',
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
    required RecoverBullTorRoute route,
  }) async {
    final url = validateRecoverBullServerUrl(
      await _recoverbullSettingsDatasource.fetch(),
    );
    final request = storeRequest;
    await _timed(
      'store_key',
      () => request != null
          ? request(url, route.client, backupId, password, salt, backupKey)
          : KeyServer(address: url, client: route.client).storeBackupKey(
              backupId: backupId,
              password: password,
              backupKey: backupKey,
              salt: salt,
            ),
    );
  }

  Future<List<int>> fetch(
    List<int> backupId,
    List<int> password,
    List<int> salt, {
    required RecoverBullTorRoute route,
  }) async {
    final result = await fetchWithStatus(
      backupId,
      password,
      salt,
      route: route,
    );
    return result.backupKey;
  }

  Future<FetchBackupKeyResult> fetchWithStatus(
    List<int> backupId,
    List<int> password,
    List<int> salt, {
    required RecoverBullTorRoute route,
  }) async {
    final url = validateRecoverBullServerUrl(
      await _recoverbullSettingsDatasource.fetch(),
    );
    final request = fetchRequest;
    return await _timed(
      'fetch_key',
      () => request != null
          ? request(url, route.client, backupId, password, salt)
          : KeyServer(
              address: url,
              client: route.client,
            ).fetchBackupKeyWithStatus(
              backupId: backupId,
              password: password,
              salt: salt,
            ),
    );
  }

  Future<void> trash(
    List<int> backupId,
    List<int> password,
    List<int> salt, {
    required RecoverBullTorRoute route,
  }) async {
    await trashWithStatus(backupId, password, salt, route: route);
  }

  Future<FetchBackupKeyResult> trashWithStatus(
    List<int> backupId,
    List<int> password,
    List<int> salt, {
    required RecoverBullTorRoute route,
  }) async {
    final url = validateRecoverBullServerUrl(
      await _recoverbullSettingsDatasource.fetch(),
    );
    final request = trashRequest;
    return await _timed(
      'trash_key',
      () => request != null
          ? request(url, route.client, backupId, password, salt)
          : KeyServer(
              address: url,
              client: route.client,
            ).trashBackupKeyWithStatus(
              backupId: backupId,
              password: password,
              salt: salt,
            ),
    );
  }

  Future<void> checkConnection(RecoverBullTorRoute route) async {
    final url = validateRecoverBullServerUrl(
      await _recoverbullSettingsDatasource.fetch(),
    );
    final request = infoRequest;
    await _timed(
      'server_health',
      () => request != null
          ? request(url, route.client)
          : KeyServer(address: url, client: route.client).infos(),
      timeout: healthCheckTimeout,
    );
  }

  Future<AttemptsResult> attempts({
    required RecoverBullTorRoute route,
    String? etag,
    List<String> backupIdHashes = const [],
  }) async {
    final url = validateRecoverBullServerUrl(
      await _recoverbullSettingsDatasource.fetch(),
    );
    try {
      final result = await _timed(
        'attempts_poll',
        () => attemptsRequest != null
            ? attemptsRequest!(url, route.client, etag, backupIdHashes)
            : KeyServer(
                address: url,
                client: route.client,
              ).attempts(etag: etag, backupIdHashes: backupIdHashes),
      );
      log.fine(
        'recoverbull.attempts.poll.succeeded '
        'outcome=${result is AttemptsNotModified ? 'not_modified' : 'modified'} '
        'matching_count=${result is AttemptsModified ? result.matchingEntries.length : 0}',
      );
      return result;
    } on KeyServerException catch (e) {
      final code = e.code;
      if (code == 429) {
        log.warning(
          'recoverbull.attempts.poll.rate_limited code=429 '
          'attempts=${e.attempts ?? 'unknown'} '
          'retry_after_seconds=${e.retryAfter?.inSeconds ?? 'unknown'}',
        );
      } else {
        log.warning(
          'recoverbull.attempts.poll.unavailable code=${code ?? 'unknown'}',
        );
      }
      rethrow;
    } on TimeoutException {
      log.warning('recoverbull.attempts.poll.timeout');
      rethrow;
    } catch (e, st) {
      log.error(
        'recoverbull.attempts.poll.unexpected error_type=${e.runtimeType}',
        trace: st,
      );
      rethrow;
    }
  }
}

/// Production bridge for the pinned client. It filters before returning so a
/// complete public `/attempts` map never enters package state.
final class RecoverBullAttemptMonitoringRemoteAdapter
    implements RecoverBullAttemptMonitoringRemotePort {
  final RecoverBullRemoteDatasource datasource;
  final Future<RecoverBullTorRoute> Function() routeFactory;

  const RecoverBullAttemptMonitoringRemoteAdapter({
    required this.datasource,
    required this.routeFactory,
  });

  @override
  Future<RecoverBullAttemptsSnapshot?> poll({
    required String? etag,
    required List<String> backupDigests,
  }) async {
    final route = await routeFactory();
    try {
      final result = await datasource.attempts(
        route: route,
        etag: etag,
        backupIdHashes: backupDigests,
      );
      return switch (result) {
        AttemptsNotModified() => RecoverBullAttemptsSnapshot(
          collectionStartedAt: DateTime.fromMillisecondsSinceEpoch(
            0,
            isUtc: true,
          ),
          totalAttempts: {},
          notModified: true,
        ),
        AttemptsModified(
          :final etag,
          :final collectionStartedAt,
          :final totalEntries,
          :final matchingEntries,
        ) =>
          RecoverBullAttemptsSnapshot(
            etag: etag,
            collectionStartedAt: collectionStartedAt,
            totalEntries: totalEntries,
            totalAttempts: {
              for (final entry in matchingEntries)
                _decodeDigest(entry.idHash): entry.totalAttempts,
            },
            windowStartedAt: {
              for (final entry in matchingEntries)
                _decodeDigest(entry.idHash): entry.windowStartedAt,
            },
          ),
      };
    } on KeyServerException catch (error) {
      if (error.code == 404 || error.code == 503) {
        return RecoverBullAttemptsSnapshot(
          collectionStartedAt: DateTime.fromMillisecondsSinceEpoch(
            0,
            isUtc: true,
          ),
          totalAttempts: {},
          serviceBusy: true,
        );
      }
      if (error.code == 429) {
        return RecoverBullAttemptsSnapshot(
          collectionStartedAt: DateTime.fromMillisecondsSinceEpoch(
            0,
            isUtc: true,
          ),
          totalAttempts: const {},
          serviceBusy: true,
        );
      }
      rethrow;
    } finally {
      await route.closeQuietly();
    }
  }

  static List<int> _decodeDigest(String value) => convert.hex.decode(value);
}
