import 'dart:convert';

import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_local_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/tor/domain/ports/tor_config_port.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:hex/hex.dart';
import 'package:recoverbull/recoverbull.dart' as recoverbull;

/// Data boundary for the RecoverBull key server and vault crypto. Catches the
/// foreign exceptions the datasources/SDK throw, logs the raw reason, and
/// returns a [RecoverBullCoreFailure] — no exception crosses this boundary.
class RecoverBullRepository {
  final RecoverBullRemoteDatasource remoteDatasource;
  final RecoverbullSettingsDatasource recoverbullSettingsDatasource;
  final TorConfigPort torConfigPort;

  RecoverBullRepository({
    required this.remoteDatasource,
    required this.recoverbullSettingsDatasource,
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
        HEX.decode(vaultKey),
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
        HEX.decode(vaultKey),
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
        HEX.decode(identifier),
        utf8.encode(password),
        HEX.decode(salt),
        HEX.decode(vaultKey),
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
        HEX.decode(identifier),
        utf8.encode(password),
        HEX.decode(salt),
        externalProxy: externalProxy,
      );
      return Ok(HEX.encode(vaultKey));
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
      HEX.decode(identifier),
      utf8.encode(password),
      HEX.decode(salt),
      externalProxy: externalProxy,
    );
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
  RecoverBullCoreFailure _mapKeyServer(recoverbull.KeyServerException e) {
    final code = e.code;
    if (code == 401) return KeyServerInvalidCredentialsFailure(e.toString());
    if (code == 429) {
      final requestedAt = e.requestedAt;
      final cooldown = e.cooldownInMinutes;
      final retryIn = (requestedAt != null && cooldown != null)
          ? requestedAt
                .add(Duration(minutes: cooldown))
                .difference(DateTime.now())
          : null;
      return KeyServerRateLimitedFailure(
        retryIn: retryIn,
        logMessage: e.toString(),
      );
    }
    if (code != null && code >= 400 && code < 500) {
      return KeyServerRejectedFailure(e.toString());
    }
    return KeyServerUnavailableFailure(e.toString());
  }
}
