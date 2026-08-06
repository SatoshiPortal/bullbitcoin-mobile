import 'dart:convert';

import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_local_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_telemetry_datasource.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/key_server_telemetry.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:convert/convert.dart' as convert;
import 'package:recoverbull/recoverbull.dart' as recoverbull;
import 'package:bull_tor/tor.dart';
import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';

/// Data boundary for the RecoverBull key server and vault crypto. Catches the
/// foreign exceptions the datasources/SDK throw, logs the raw reason, and
/// returns a [RecoverBullCoreFailure] — no exception crosses this boundary.
class RecoverBullRepositoryImpl implements RecoverBullRepository {
  final RecoverBullRemoteDatasource _remoteDatasource;
  final RecoverbullSettingsDatasource _recoverbullSettingsDatasource;
  final RecoverbullTelemetryDatasource _recoverbullTelemetryDatasource;

  factory RecoverBullRepositoryImpl({
    required RecoverBullRemoteDatasource remoteDatasource,
    required RecoverbullSettingsDatasource recoverbullSettingsDatasource,
    required RecoverbullTelemetryDatasource recoverbullTelemetryDatasource,
  }) => RecoverBullRepositoryImpl._(
    remoteDatasource,
    recoverbullSettingsDatasource,
    recoverbullTelemetryDatasource,
  );

  RecoverBullRepositoryImpl._(
    this._remoteDatasource,
    this._recoverbullSettingsDatasource,
    this._recoverbullTelemetryDatasource,
  );

  /// Builds an encrypted vault file for [plaintext] under [vaultKey] and stamps
  /// the BIP85 [derivationPath] into it. (Assembly lives here, not in the
  /// use-case.)
  @override
  Result<EncryptedVault, RecoverBullCoreFailure> createVault({
    required String vaultKey,
    required String plaintext,
    required String derivationPath,
  }) {
    try {
      final encryptedBackup = RecoverBullDatasource.create(
        utf8.encode(plaintext),
        convert.hex.decode(_normalizeHex(vaultKey)),
      );
      final mapBackup = json.decode(encryptedBackup) as Map<String, dynamic>;
      mapBackup['path'] = derivationPath;
      return Ok(EncryptedVault(file: json.encode(mapBackup)));
    } catch (e, st) {
      log.severe(
        message: 'createVault failed',
        error: 'Vault processing failed',
        trace: st,
      );
      return const Err(
        RecoverBullUnexpectedCoreFailure('Vault processing failed'),
      );
    }
  }

  /// Decrypts [vault] with [vaultKey] and decodes it into a [DecryptedVault].
  /// Wrong key / corrupt data surface as a failure, never an exception.
  @override
  Result<DecryptedVault, RecoverBullCoreFailure> restoreVault({
    required EncryptedVault vault,
    required String vaultKey,
  }) {
    try {
      final decryptedBytes = RecoverBullDatasource.restore(
        vault.toFile(),
        convert.hex.decode(_normalizeHex(vaultKey)),
      );
      final plaintext = utf8.decode(decryptedBytes);
      final decoded = json.decode(plaintext) as Map<String, dynamic>;
      return Ok(DecryptedVault.fromJson(decoded));
    } catch (e, st) {
      log.severe(
        message: 'restoreVault failed',
        error: 'Vault processing failed',
        trace: st,
      );
      return const Err(
        RecoverBullUnexpectedCoreFailure('Vault processing failed'),
      );
    }
  }

  @override
  Future<Result<Null, RecoverBullCoreFailure>> storeVaultKey(
    String identifier,
    String password,
    String salt,
    String vaultKey,
    TorProxyEndpoint endpoint,
  ) async {
    try {
      await _remoteDatasource.store(
        convert.hex.decode(_normalizeHex(identifier)),
        utf8.encode(password),
        convert.hex.decode(_normalizeHex(salt)),
        convert.hex.decode(_normalizeHex(vaultKey)),
        endpoint: endpoint,
      );
      return const Ok(null);
    } on recoverbull.KeyServerException catch (e, st) {
      log.severe(
        message: 'storeVaultKey failed',
        error: 'Vault key processing failed',
        trace: st,
      );
      return Err(_mapKeyServer(e));
    } catch (e, st) {
      log.severe(
        message: 'storeVaultKey failed',
        error: 'Vault key processing failed',
        trace: st,
      );
      return const Err(
        RecoverBullUnexpectedCoreFailure('Vault key processing failed'),
      );
    }
  }

  @override
  Future<Result<String, RecoverBullCoreFailure>> fetchVaultKey(
    String identifier,
    String password,
    String salt,
    TorProxyEndpoint endpoint,
  ) async {
    try {
      final vaultKey = await _remoteDatasource.fetch(
        convert.hex.decode(_normalizeHex(identifier)),
        utf8.encode(password),
        convert.hex.decode(_normalizeHex(salt)),
        endpoint: endpoint,
      );
      return Ok(convert.hex.encode(vaultKey));
    } on recoverbull.KeyServerException catch (e, st) {
      log.severe(
        message: 'fetchVaultKey failed',
        error: 'Vault key processing failed',
        trace: st,
      );
      return Err(_mapKeyServer(e));
    } catch (e, st) {
      log.severe(
        message: 'fetchVaultKey failed',
        error: 'Vault key processing failed',
        trace: st,
      );
      return const Err(
        RecoverBullUnexpectedCoreFailure('Vault key processing failed'),
      );
    }
  }

  @override
  Future<void> trashVaultKey(
    String identifier,
    String password,
    String salt,
    TorProxyEndpoint endpoint,
  ) async {
    await _remoteDatasource.trash(
      convert.hex.decode(_normalizeHex(identifier)),
      utf8.encode(password),
      convert.hex.decode(_normalizeHex(salt)),
      endpoint: endpoint,
    );
  }

  /// Fetch with the identifier's exact attempt counters — the freshest
  /// telemetry signal, available even when `/attempts` is overloaded.
  @override
  Future<Result<VaultKeyFetchResult, RecoverBullCoreFailure>>
  fetchVaultKeyWithStatus(
    String identifier,
    String password,
    String salt,
    TorProxyEndpoint endpoint,
  ) async {
    try {
      final result = await _remoteDatasource.fetchWithStatus(
        convert.hex.decode(_normalizeHex(identifier)),
        utf8.encode(password),
        convert.hex.decode(_normalizeHex(salt)),
        endpoint: endpoint,
      );
      return Ok(
        VaultKeyFetchResult(
          vaultKey: convert.hex.encode(result.backupKey),
          attemptStatus: _mapAttemptStatus(result.attemptStatus),
        ),
      );
    } on recoverbull.KeyServerException catch (e, st) {
      log.severe(
        message: 'fetchVaultKeyWithStatus failed',
        error: e,
        trace: st,
      );
      return Err(_mapKeyServer(e));
    } catch (e, st) {
      log.severe(
        message: 'fetchVaultKeyWithStatus failed',
        error: e,
        trace: st,
      );
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }

  /// Trash with the identifier's exact attempt counters.
  @override
  Future<Result<VaultKeyFetchResult, RecoverBullCoreFailure>>
  trashVaultKeyWithStatus(
    String identifier,
    String password,
    String salt,
    TorProxyEndpoint endpoint,
  ) async {
    try {
      final result = await _remoteDatasource.trashWithStatus(
        convert.hex.decode(_normalizeHex(identifier)),
        utf8.encode(password),
        convert.hex.decode(_normalizeHex(salt)),
        endpoint: endpoint,
      );
      return Ok(
        VaultKeyFetchResult(
          vaultKey: convert.hex.encode(result.backupKey),
          attemptStatus: _mapAttemptStatus(result.attemptStatus),
        ),
      );
    } on recoverbull.KeyServerException catch (e, st) {
      log.severe(
        message: 'trashVaultKeyWithStatus failed',
        error: e,
        trace: st,
      );
      return Err(_mapKeyServer(e));
    } catch (e, st) {
      log.severe(
        message: 'trashVaultKeyWithStatus failed',
        error: e,
        trace: st,
      );
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }

  /// The server info's telemetry metadata (wipe detection + map capacity).
  @override
  Future<Result<KeyServerInfo, RecoverBullCoreFailure>> fetchServerInfo(
    TorProxyEndpoint endpoint, {
    String? expectedCanary,
  }) async {
    try {
      final info = await _remoteDatasource.infos(
        endpoint: endpoint,
        expectedCanary: expectedCanary,
      );
      return Ok(
        KeyServerInfo(
          collectionStartedAt: info.attemptsCollectionStartedAt,
          maxAttemptIdentifiers: info.maxAttemptIdentifiers,
        ),
      );
    } on recoverbull.KeyServerException catch (e, st) {
      log.severe(message: 'fetchServerInfo failed', error: e, trace: st);
      return Err(_mapKeyServer(e));
    } catch (e, st) {
      log.severe(message: 'fetchServerInfo failed', error: e, trace: st);
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }

  /// Conditional `GET /attempts`. Only the entries matching [backupIds] or
  /// [backupIdHashes] are returned; the full snapshot never leaves the
  /// client's worker isolate.
  @override
  Future<Result<TelemetrySnapshotResult, RecoverBullCoreFailure>>
  fetchTelemetrySnapshot(
    TorProxyEndpoint endpoint, {
    String? etag,
    List<List<int>> backupIds = const [],
    List<String> backupIdHashes = const [],
  }) async {
    try {
      final result = await _remoteDatasource.attempts(
        endpoint: endpoint,
        etag: etag,
        backupIds: backupIds,
        backupIdHashes: backupIdHashes,
      );
      return Ok(_mapSnapshot(result));
    } on recoverbull.KeyServerException catch (e, st) {
      log.severe(message: 'fetchTelemetrySnapshot failed', error: e, trace: st);
      return Err(_mapKeyServer(e));
    } catch (e, st) {
      log.severe(message: 'fetchTelemetrySnapshot failed', error: e, trace: st);
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }

  // --- Telemetry baseline persistence (scoped per key-server URL) ---

  @override
  Future<TelemetryServerState?> fetchTelemetryServerState(String serverUrl) {
    return _recoverbullTelemetryDatasource.fetchServerState(serverUrl);
  }

  @override
  Future<void> upsertTelemetryServerState(TelemetryServerState state) {
    return _recoverbullTelemetryDatasource.upsertServerState(state);
  }

  @override
  Future<List<TelemetryBackupState>> fetchTelemetryBackups(String serverUrl) {
    return _recoverbullTelemetryDatasource.fetchBackups(serverUrl);
  }

  @override
  Future<TelemetryBackupState?> fetchTelemetryBackup(
    String serverUrl,
    String backupIdHash,
  ) {
    return _recoverbullTelemetryDatasource.fetchBackup(serverUrl, backupIdHash);
  }

  @override
  Future<void> upsertTelemetryBackup(TelemetryBackupState state) {
    return _recoverbullTelemetryDatasource.upsertBackup(state);
  }

  /// The key-server URL changed: every telemetry row of the old server is
  /// dropped — identifiers and snapshots from different servers are
  /// unrelated.
  @override
  Future<void> deleteTelemetryForServer(String serverUrl) {
    return _recoverbullTelemetryDatasource.deleteAllForServer(serverUrl);
  }

  /// App data reset: wipe every telemetry row.
  @override
  Future<void> clearTelemetry() {
    return _recoverbullTelemetryDatasource.clearAll();
  }

  KeyServerAttemptStatus? _mapAttemptStatus(recoverbull.AttemptStatus? s) {
    if (s == null) return null;
    return KeyServerAttemptStatus(
      totalAttempts: s.totalAttempts,
      failedAttempts: s.failedAttempts,
      remainingAttempts: s.remainingAttempts,
      windowStartedAt: s.windowStartedAt,
      previousAttemptAt: s.previousAttemptAt,
      resetsAt: s.resetsAt,
    );
  }

  TelemetrySnapshotResult _mapSnapshot(recoverbull.AttemptsResult result) {
    return switch (result) {
      recoverbull.AttemptsNotModified() => const TelemetrySnapshotNotModified(),
      recoverbull.AttemptsModified() => TelemetrySnapshotModified(
        etag: result.etag,
        maxAgeSeconds: result.maxAgeSeconds,
        collectionStartedAt: result.collectionStartedAt,
        totalEntries: result.totalEntries,
        matchingEntries: result.matchingEntries
            .map(
              (e) => KeyServerAttemptEntry(
                idHash: e.idHash,
                totalAttempts: e.totalAttempts,
                failedAttempts: e.failedAttempts,
                windowStartedAt: e.windowStartedAt,
                lastAttemptAt: e.lastAttemptAt,
              ),
            )
            .toList(),
      ),
    };
  }

  /// Health probe: completes normally when the server is reachable, throws
  /// otherwise. Kept throwing (not Result) on purpose so the shared status
  /// checker — `CheckServerConnectionUsecase`, which turns the throw/return
  /// into the bool — is unaffected by the Result migration.
  @override
  Future<void> checkConnection(TorProxyEndpoint endpoint) async {
    await _remoteDatasource.checkConnection(endpoint);
  }

  @override
  Future<Uri> fetchUrl() async {
    return await _recoverbullSettingsDatasource.fetch();
  }

  @override
  Future<void> storeUrl(Uri url) async {
    await _recoverbullSettingsDatasource.store(url);
  }

  @override
  Future<void> allowPermission(bool isGranted) async {
    await _recoverbullSettingsDatasource.allowPermission(isGranted);
  }

  @override
  Future<bool> fetchPermission() async {
    return await _recoverbullSettingsDatasource.fetchPermission();
  }

  // The client classifies key-server errors by HTTP status alone: 429 is
  // always the targeted per-identifier lockout, 503 is always service-wide
  // pressure (exhausted global bucket, full rate-limit map, or the proxy's own
  // edge limit, which the deployment rewrites to 503). So the status is enough
  // here — there is no targeted-vs-global ambiguity left to disentangle.
  RecoverBullCoreFailure _mapKeyServer(recoverbull.KeyServerException e) {
    final code = e.code;
    if (e is recoverbull.KeyServerRateLimitedException || code == 429) {
      return KeyServerRateLimitedFailure(
        retryIn: _retryIn(e),
        logMessage: e.toString(),
      );
    }
    if (code == 401) return KeyServerInvalidCredentialsFailure(e.toString());
    if (code != null && code >= 400 && code < 500) {
      return KeyServerRejectedFailure(e.toString());
    }
    // 503 is the server explicitly reporting service-wide pressure. Keep it
    // apart from a server we could not reach at all: only the former may be
    // shown to the user as "the server is busy".
    if (code == 503) return KeyServerBusyFailure(e.toString());
    return KeyServerUnavailableFailure(e.toString());
  }

  Duration? _retryIn(recoverbull.KeyServerException e) {
    final requestedAt = e.requestedAt;
    final cooldown = e.cooldownInMinutes;
    return (requestedAt != null && cooldown != null)
        ? requestedAt
              .add(Duration(minutes: cooldown))
              .difference(DateTime.now())
        : null;
  }

  /// Vault keys and server identifiers reach us as raw user input (typed or
  /// pasted — the recovery screen has no input formatter). Strip formatting
  /// whitespace before decoding so a spaced or newline-terminated key (the
  /// reveal screen shows the key in 4-char groups) still decodes.
  String _normalizeHex(String input) => input.replaceAll(RegExp(r'\s'), '');
}
