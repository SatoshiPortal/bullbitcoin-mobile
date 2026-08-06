import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/key_server_telemetry.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';
import 'package:bull_tor/tor.dart';

abstract interface class RecoverBullRepository {
  @useResult
  Result<EncryptedVault, RecoverBullCoreFailure> createVault({
    required String vaultKey,
    required String plaintext,
    required String derivationPath,
  });

  @useResult
  Result<DecryptedVault, RecoverBullCoreFailure> restoreVault({
    required EncryptedVault vault,
    required String vaultKey,
  });

  @useResult
  Future<Result<Null, RecoverBullCoreFailure>> storeVaultKey(
    String identifier,
    String password,
    String salt,
    String vaultKey,
    TorProxyEndpoint endpoint,
  );

  @useResult
  Future<Result<String, RecoverBullCoreFailure>> fetchVaultKey(
    String identifier,
    String password,
    String salt,
    TorProxyEndpoint endpoint,
  );

  Future<void> trashVaultKey(
    String identifier,
    String password,
    String salt,
    TorProxyEndpoint endpoint,
  );

  Future<void> checkConnection(TorProxyEndpoint endpoint);

  Future<Uri> fetchUrl();

  Future<void> storeUrl(Uri url);

  Future<void> allowPermission(bool isGranted);

  Future<bool> fetchPermission();

  // --- Brute-force telemetry ---
  //
  // All telemetry is advisory: the server cannot distinguish an attacker from
  // the user or another of the user's devices, and a compromised server can
  // fabricate or suppress counters. Nothing here ever acts automatically.

  /// Fetch with the identifier's exact attempt counters — the freshest
  /// telemetry signal, available even when `/attempts` is rate limited.
  @useResult
  Future<Result<VaultKeyFetchResult, RecoverBullCoreFailure>>
  fetchVaultKeyWithStatus(
    String identifier,
    String password,
    String salt,
    TorProxyEndpoint endpoint,
  );

  /// Trash with the identifier's exact attempt counters.
  @useResult
  Future<Result<VaultKeyFetchResult, RecoverBullCoreFailure>>
  trashVaultKeyWithStatus(
    String identifier,
    String password,
    String salt,
    TorProxyEndpoint endpoint,
  );

  /// The server info's telemetry metadata (wipe detection + map capacity).
  @useResult
  Future<Result<KeyServerInfo, RecoverBullCoreFailure>> fetchServerInfo(
    TorProxyEndpoint endpoint, {
    String? expectedCanary,
  });

  /// Conditional `GET /attempts`. Only the entries matching [backupIds] or
  /// [backupIdHashes] are returned; the full snapshot never leaves the
  /// client's worker isolate.
  @useResult
  Future<Result<TelemetrySnapshotResult, RecoverBullCoreFailure>>
  fetchTelemetrySnapshot(
    TorProxyEndpoint endpoint, {
    String? etag,
    List<List<int>> backupIds = const [],
    List<String> backupIdHashes = const [],
  });

  // --- Telemetry baseline persistence (scoped per key-server URL) ---

  Future<TelemetryServerState?> fetchTelemetryServerState(String serverUrl);

  Future<void> upsertTelemetryServerState(TelemetryServerState state);

  Future<List<TelemetryBackupState>> fetchTelemetryBackups(String serverUrl);

  Future<TelemetryBackupState?> fetchTelemetryBackup(
    String serverUrl,
    String backupIdHash,
  );

  Future<void> upsertTelemetryBackup(TelemetryBackupState state);

  /// The key-server URL changed: every telemetry row of the old server is
  /// dropped — identifiers and snapshots from different servers are
  /// unrelated.
  Future<void> deleteTelemetryForServer(String serverUrl);

  /// App data reset: wipe every telemetry row.
  Future<void> clearTelemetry();
}
