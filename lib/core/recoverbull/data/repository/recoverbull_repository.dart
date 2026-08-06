import 'dart:convert';

import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_local_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_telemetry_datasource.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/key_server_telemetry.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/tor/domain/ports/tor_config_port.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:convert/convert.dart' as convert;
import 'package:recoverbull/recoverbull.dart' as recoverbull;

/// Data boundary for the RecoverBull key server and vault crypto. Catches the
/// foreign exceptions the datasources/SDK throw, logs the raw reason, and
/// returns a [RecoverBullCoreFailure] — no exception crosses this boundary.
class RecoverBullRepository {
  final RecoverBullRemoteDatasource remoteDatasource;
  final RecoverbullSettingsDatasource recoverbullSettingsDatasource;
  final RecoverbullTelemetryDatasource recoverbullTelemetryDatasource;
  final TorConfigPort torConfigPort;

  RecoverBullRepository({
    required this.remoteDatasource,
    required this.recoverbullSettingsDatasource,
    required this.recoverbullTelemetryDatasource,
    required this.torConfigPort,
  });

  /// Builds an encrypted vault file for [plaintext] under [vaultKey] and stamps
  /// the BIP85 [derivationPath] into it. (Assembly lives here, not in the
  /// use-case.)
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
      log.severe(message: 'createVault failed', error: e, trace: st);
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }

  /// Decrypts [vault] with [vaultKey] and decodes it into a [DecryptedVault].
  /// Wrong key / corrupt data surface as a failure, never an exception.
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
      log.severe(message: 'restoreVault failed', error: e, trace: st);
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }

  Future<Result<Null, RecoverBullCoreFailure>> storeVaultKey(
    String identifier,
    String password,
    String salt,
    String vaultKey,
  ) async {
    try {
      final externalProxy = await torConfigPort.getAvailableExternalTorConfig();
      await remoteDatasource.store(
        convert.hex.decode(_normalizeHex(identifier)),
        utf8.encode(password),
        convert.hex.decode(_normalizeHex(salt)),
        convert.hex.decode(_normalizeHex(vaultKey)),
        externalProxy: externalProxy,
      );
      return const Ok(null);
    } on recoverbull.KeyServerException catch (e, st) {
      log.severe(message: 'storeVaultKey failed', error: e, trace: st);
      return Err(_mapKeyServer(e));
    } catch (e, st) {
      log.severe(message: 'storeVaultKey failed', error: e, trace: st);
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }

  Future<Result<String, RecoverBullCoreFailure>> fetchVaultKey(
    String identifier,
    String password,
    String salt,
  ) async {
    try {
      final externalProxy = await torConfigPort.getAvailableExternalTorConfig();
      final vaultKey = await remoteDatasource.fetch(
        convert.hex.decode(_normalizeHex(identifier)),
        utf8.encode(password),
        convert.hex.decode(_normalizeHex(salt)),
        externalProxy: externalProxy,
      );
      return Ok(convert.hex.encode(vaultKey));
    } on recoverbull.KeyServerException catch (e, st) {
      log.severe(message: 'fetchVaultKey failed', error: e, trace: st);
      return Err(_mapKeyServer(e));
    } catch (e, st) {
      log.severe(message: 'fetchVaultKey failed', error: e, trace: st);
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }

  Future<void> trashVaultKey(
    String identifier,
    String password,
    String salt,
  ) async {
    final externalProxy = await torConfigPort.getAvailableExternalTorConfig();
    await remoteDatasource.trash(
      convert.hex.decode(_normalizeHex(identifier)),
      utf8.encode(password),
      convert.hex.decode(_normalizeHex(salt)),
      externalProxy: externalProxy,
    );
  }

  /// Fetch with the identifier's exact attempt counters — the freshest
  /// telemetry signal, available even when `/attempts` is overloaded.
  Future<Result<VaultKeyFetchResult, RecoverBullCoreFailure>>
  fetchVaultKeyWithStatus(
    String identifier,
    String password,
    String salt,
  ) async {
    try {
      final externalProxy = await torConfigPort.getAvailableExternalTorConfig();
      final result = await remoteDatasource.fetchWithStatus(
        convert.hex.decode(_normalizeHex(identifier)),
        utf8.encode(password),
        convert.hex.decode(_normalizeHex(salt)),
        externalProxy: externalProxy,
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
  Future<Result<VaultKeyFetchResult, RecoverBullCoreFailure>>
  trashVaultKeyWithStatus(
    String identifier,
    String password,
    String salt,
  ) async {
    try {
      final externalProxy = await torConfigPort.getAvailableExternalTorConfig();
      final result = await remoteDatasource.trashWithStatus(
        convert.hex.decode(_normalizeHex(identifier)),
        utf8.encode(password),
        convert.hex.decode(_normalizeHex(salt)),
        externalProxy: externalProxy,
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
  Future<Result<KeyServerInfo, RecoverBullCoreFailure>> fetchServerInfo({
    String? expectedCanary,
  }) async {
    try {
      final externalProxy = await torConfigPort.getAvailableExternalTorConfig();
      final info = await remoteDatasource.infos(
        externalProxy: externalProxy,
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
  Future<Result<TelemetrySnapshotResult, RecoverBullCoreFailure>>
  fetchTelemetrySnapshot({
    String? etag,
    List<List<int>> backupIds = const [],
    List<String> backupIdHashes = const [],
  }) async {
    try {
      final externalProxy = await torConfigPort.getAvailableExternalTorConfig();
      final result = await remoteDatasource.attempts(
        etag: etag,
        backupIds: backupIds,
        backupIdHashes: backupIdHashes,
        externalProxy: externalProxy,
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

  Future<RecoverbullTelemetryServerRow?> fetchTelemetryServerState(
    String serverUrl,
  ) {
    return recoverbullTelemetryDatasource.fetchServerState(serverUrl);
  }

  Future<void> upsertTelemetryServerState(RecoverbullTelemetryServerRow row) {
    return recoverbullTelemetryDatasource.upsertServerState(row);
  }

  Future<List<RecoverbullTelemetryBackupRow>> fetchTelemetryBackups(
    String serverUrl,
  ) {
    return recoverbullTelemetryDatasource.fetchBackups(serverUrl);
  }

  Future<RecoverbullTelemetryBackupRow?> fetchTelemetryBackup(
    String serverUrl,
    String backupIdHash,
  ) {
    return recoverbullTelemetryDatasource.fetchBackup(serverUrl, backupIdHash);
  }

  Future<void> upsertTelemetryBackup(RecoverbullTelemetryBackupRow row) {
    return recoverbullTelemetryDatasource.upsertBackup(row);
  }

  /// The key-server URL changed: every telemetry row of the old server is
  /// dropped — identifiers and snapshots from different servers are
  /// unrelated.
  Future<void> deleteTelemetryForServer(String serverUrl) {
    return recoverbullTelemetryDatasource.deleteAllForServer(serverUrl);
  }

  /// App data reset: wipe every telemetry row.
  Future<void> clearTelemetry() {
    return recoverbullTelemetryDatasource.clearAll();
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
  Future<void> checkConnection() async {
    final externalProxy = await torConfigPort.getAvailableExternalTorConfig();
    await remoteDatasource.checkConnection(externalProxy: externalProxy);
  }

  Future<Uri> fetchUrl() async {
    return await recoverbullSettingsDatasource.fetch();
  }

  Future<void> storeUrl(Uri url) async {
    await recoverbullSettingsDatasource.store(url);
  }

  Future<void> allowPermission(bool isGranted) async {
    await recoverbullSettingsDatasource.allowPermission(isGranted);
  }

  Future<bool> fetchPermission() async {
    return await recoverbullSettingsDatasource.fetchPermission();
  }

  // Mirrors the legacy `ServerError.fromException`, null-safe on the 429 path.
  // The client's dedicated 429/503 subtypes are matched first: they carry the
  // targeted-vs-global and capacity-vs-busy distinctions the telemetry
  // warnings need.
  RecoverBullCoreFailure _mapKeyServer(recoverbull.KeyServerException e) {
    final code = e.code;
    if (e is recoverbull.KeyServerRateLimitedException) {
      return KeyServerTargetedRateLimitedFailure(
        retryIn: _retryIn(e),
        logMessage: e.toString(),
      );
    }
    if (e is recoverbull.KeyServerOverloadedException) {
      return KeyServerOverloadedFailure(e.toString());
    }
    if (e is recoverbull.KeyServerCapacityException) {
      return KeyServerCapacityFailure(e.toString());
    }
    if (code == 401) return KeyServerInvalidCredentialsFailure(e.toString());
    if (code == 429) {
      return KeyServerRateLimitedFailure(
        retryIn: _retryIn(e),
        logMessage: e.toString(),
      );
    }
    if (code != null && code >= 400 && code < 500) {
      return KeyServerRejectedFailure(e.toString());
    }
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
