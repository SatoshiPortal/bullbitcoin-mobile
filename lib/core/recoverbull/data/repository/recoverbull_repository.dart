import 'dart:convert';

import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_local_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:convert/convert.dart' as convert;
import 'package:recoverbull/recoverbull.dart' as recoverbull;
import 'package:bull_tor/tor.dart';

/// Data boundary for the RecoverBull key server and vault crypto. Catches the
/// foreign exceptions the datasources/SDK throw, logs the raw reason, and
/// returns a [RecoverBullCoreFailure] — no exception crosses this boundary.
class RecoverBullRepository {
  final RecoverBullRemoteDatasource remoteDatasource;
  final RecoverbullSettingsDatasource recoverbullSettingsDatasource;

  RecoverBullRepository({
    required this.remoteDatasource,
    required this.recoverbullSettingsDatasource,
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

  Future<Result<Null, RecoverBullCoreFailure>> storeVaultKey(
    String identifier,
    String password,
    String salt,
    String vaultKey,
    TorProxyEndpoint endpoint,
  ) async {
    try {
      await remoteDatasource.store(
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

  Future<Result<String, RecoverBullCoreFailure>> fetchVaultKey(
    String identifier,
    String password,
    String salt,
    TorProxyEndpoint endpoint,
  ) async {
    try {
      final vaultKey = await remoteDatasource.fetch(
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

  Future<void> trashVaultKey(
    String identifier,
    String password,
    String salt,
    TorProxyEndpoint endpoint,
  ) async {
    await remoteDatasource.trash(
      convert.hex.decode(_normalizeHex(identifier)),
      utf8.encode(password),
      convert.hex.decode(_normalizeHex(salt)),
      endpoint: endpoint,
    );
  }

  /// Health probe: completes normally when the server is reachable, throws
  /// otherwise. Kept throwing (not Result) on purpose so the shared status
  /// checker — `CheckServerConnectionUsecase`, which turns the throw/return
  /// into the bool — is unaffected by the Result migration.
  Future<void> checkConnection(TorProxyEndpoint endpoint) async {
    await remoteDatasource.checkConnection(endpoint);
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

  /// Vault keys and server identifiers reach us as raw user input (typed or
  /// pasted — the recovery screen has no input formatter). Strip formatting
  /// whitespace before decoding so a spaced or newline-terminated key (the
  /// reveal screen shows the key in 4-char groups) still decodes.
  String _normalizeHex(String input) => input.replaceAll(RegExp(r'\s'), '');
}
