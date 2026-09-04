import 'dart:convert';
import 'dart:isolate';

import './datasources/recoverbull_local_datasource.dart';
import './datasources/recoverbull_remote_datasource.dart';
import './datasources/recoverbull_settings_datasource.dart';
import '../domain/entities/decrypted_vault.dart';
import '../domain/entities/encrypted_vault.dart';
import '../domain/recoverbull_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:convert/convert.dart' as convert;
import '../utils/recoverbull_bip85.dart';
import 'package:recoverbull/recoverbull.dart' as recoverbull;
import '../domain/repositories/recoverbull_repository.dart';
import '../domain/entities/key_server_attempts.dart';
import '../domain/recoverbull_tor_route.dart';

({String file, String vaultKey}) _createVaultInWorker(
  String rootXprv,
  String plaintext,
  String derivationPath,
) {
  final vaultKey = RecoverbullBip85Utils.deriveBackupKey(
    rootXprv,
    derivationPath,
  );
  final encryptedBackup = RecoverBullDatasource.create(
    utf8.encode(plaintext),
    convert.hex.decode(vaultKey),
  );
  final mapBackup = json.decode(encryptedBackup) as Map<String, dynamic>;
  mapBackup['path'] = derivationPath;
  return (file: json.encode(mapBackup), vaultKey: vaultKey);
}

/// Data boundary for the RecoverBull key server and vault crypto. Catches the
/// foreign exceptions the datasources/SDK throw, logs the raw reason, and
/// returns a [RecoverBullFailure] — no exception crosses this boundary.
class RecoverBullRepositoryImpl implements RecoverBullRepository {
  final LogSink log;
  final RecoverBullRemoteDatasource _remoteDatasource;
  final RecoverbullSettingsDatasource _recoverbullSettingsDatasource;

  factory RecoverBullRepositoryImpl({
    required LogSink log,
    required RecoverBullRemoteDatasource remoteDatasource,
    required RecoverbullSettingsDatasource recoverbullSettingsDatasource,
  }) => RecoverBullRepositoryImpl._(
    log,
    remoteDatasource,
    recoverbullSettingsDatasource,
  );

  RecoverBullRepositoryImpl._(
    this.log,
    this._remoteDatasource,
    this._recoverbullSettingsDatasource,
  );

  /// Derives the BIP85 key from [rootXprv], encrypts [plaintext], and stamps the
  /// [derivationPath] into the resulting vault. Assembly stays at this data
  /// boundary; the worker receives no repository or external resource.
  @override
  Future<Result<({EncryptedVault vault, String vaultKey}), RecoverBullFailure>>
  createVault({
    required String rootXprv,
    required String plaintext,
    required String derivationPath,
  }) async {
    try {
      final created = await Isolate.run(
        () => _createVaultInWorker(rootXprv, plaintext, derivationPath),
      );
      return Ok((
        vault: EncryptedVault(file: created.file),
        vaultKey: created.vaultKey,
      ));
    } catch (e, st) {
      log.error(
        'createVault failed',
        error: 'Vault processing failed',
        trace: st,
      );
      return const Err(RecoverBullUnexpectedFailure('Vault processing failed'));
    }
  }

  /// Decrypts [vault] with [vaultKey] and decodes it into a [DecryptedVault].
  /// Wrong key / corrupt data surface as a failure, never an exception.
  @override
  Result<DecryptedVault, RecoverBullFailure> restoreVault({
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
      log.error(
        'restoreVault failed',
        error: 'Vault processing failed',
        trace: st,
      );
      return const Err(RecoverBullUnexpectedFailure('Vault processing failed'));
    }
  }

  @override
  Future<Result<Null, RecoverBullFailure>> storeVaultKey(
    String identifier,
    String password,
    String salt,
    String vaultKey,
    RecoverBullTorRoute route,
  ) async {
    try {
      await _remoteDatasource.store(
        convert.hex.decode(_normalizeHex(identifier)),
        utf8.encode(password),
        convert.hex.decode(_normalizeHex(salt)),
        convert.hex.decode(_normalizeHex(vaultKey)),
        route: route,
      );
      return const Ok(null);
    } on recoverbull.KeyServerException catch (e, st) {
      log.error(
        'storeVaultKey failed',
        error: 'Vault key processing failed',
        trace: st,
      );
      return Err(_mapKeyServer(e));
    } catch (e, st) {
      log.error(
        'storeVaultKey failed',
        error: 'Vault key processing failed',
        trace: st,
      );
      return const Err(
        RecoverBullUnexpectedFailure('Vault key processing failed'),
      );
    }
  }

  @override
  Future<Result<String, RecoverBullFailure>> fetchVaultKey(
    String identifier,
    String password,
    String salt,
    RecoverBullTorRoute route,
  ) async {
    try {
      final vaultKey = await _remoteDatasource.fetch(
        convert.hex.decode(_normalizeHex(identifier)),
        utf8.encode(password),
        convert.hex.decode(_normalizeHex(salt)),
        route: route,
      );
      return Ok(convert.hex.encode(vaultKey));
    } on recoverbull.KeyServerException catch (e, st) {
      log.error(
        'fetchVaultKey failed',
        error: 'Vault key processing failed',
        trace: st,
      );
      return Err(_mapKeyServer(e));
    } catch (e, st) {
      log.error(
        'fetchVaultKey failed',
        error: 'Vault key processing failed',
        trace: st,
      );
      return const Err(
        RecoverBullUnexpectedFailure('Vault key processing failed'),
      );
    }
  }

  @override
  Future<Result<VaultKeyFetchResult, RecoverBullFailure>>
  fetchVaultKeyWithStatus(
    String identifier,
    String password,
    String salt,
    RecoverBullTorRoute route,
  ) async {
    try {
      final result = await _remoteDatasource.fetchWithStatus(
        convert.hex.decode(_normalizeHex(identifier)),
        utf8.encode(password),
        convert.hex.decode(_normalizeHex(salt)),
        route: route,
      );
      return Ok(_mapFetchResult(result));
    } catch (e, st) {
      log.error(
        'fetchVaultKey failed',
        error: 'Vault key processing failed',
        trace: st,
      );
      return Err(
        e is recoverbull.KeyServerException
            ? _mapKeyServer(e)
            : const RecoverBullUnexpectedFailure('Vault key processing failed'),
      );
    }
  }

  @override
  Future<void> trashVaultKey(
    String identifier,
    String password,
    String salt,
    RecoverBullTorRoute route,
  ) async {
    await _remoteDatasource.trash(
      convert.hex.decode(_normalizeHex(identifier)),
      utf8.encode(password),
      convert.hex.decode(_normalizeHex(salt)),
      route: route,
    );
  }

  @override
  Future<Result<VaultKeyFetchResult, RecoverBullFailure>>
  trashVaultKeyWithStatus(
    String identifier,
    String password,
    String salt,
    RecoverBullTorRoute route,
  ) async {
    try {
      final result = await _remoteDatasource.trashWithStatus(
        convert.hex.decode(_normalizeHex(identifier)),
        utf8.encode(password),
        convert.hex.decode(_normalizeHex(salt)),
        route: route,
      );
      return Ok(_mapFetchResult(result));
    } catch (e, st) {
      log.error(
        'trashVaultKey failed',
        error: 'Vault key processing failed',
        trace: st,
      );
      return Err(
        e is recoverbull.KeyServerException
            ? _mapKeyServer(e)
            : const RecoverBullUnexpectedFailure('Vault key processing failed'),
      );
    }
  }

  VaultKeyFetchResult _mapFetchResult(
    recoverbull.FetchBackupKeyResult result,
  ) => VaultKeyFetchResult(
    vaultKey: convert.hex.encode(result.backupKey),
    attemptStatus: result.attemptStatus == null
        ? null
        : KeyServerAttemptStatus(
            totalAttempts: result.attemptStatus!.totalAttempts,
            failedAttempts: result.attemptStatus!.failedAttempts,
            remainingAttempts: result.attemptStatus!.remainingAttempts,
            windowStartedAt: result.attemptStatus!.windowStartedAt,
            previousAttemptAt: result.attemptStatus!.previousAttemptAt,
            resetsAt: result.attemptStatus!.resetsAt,
          ),
  );

  /// Health probe: completes normally when the server is reachable, throws
  /// otherwise. Kept throwing (not Result) on purpose so the shared status
  /// checker — `CheckServerConnectionUsecase`, which turns the throw/return
  /// into the bool — is unaffected by the Result migration.
  @override
  Future<void> checkConnection(RecoverBullTorRoute route) async {
    await _remoteDatasource.checkConnection(route);
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

  // Mirrors the legacy `ServerError.fromException`, null-safe on the 429 path.
  RecoverBullFailure _mapKeyServer(recoverbull.KeyServerException e) {
    final code = e.code;
    if (code == 401) {
      return const KeyServerInvalidCredentialsFailure(
        'Key server rejected credentials',
      );
    }
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
        logMessage: 'Key server rate limit reached',
      );
    }
    if (code != null && code >= 400 && code < 500) {
      return const KeyServerRejectedFailure('Key server rejected request');
    }
    return const KeyServerUnavailableFailure('Key server unavailable');
  }

  /// Vault keys and server identifiers reach us as raw user input (typed or
  /// pasted — the recovery screen has no input formatter). Strip formatting
  /// whitespace before decoding so a spaced or newline-terminated key (the
  /// reveal screen shows the key in 4-char groups) still decodes.
  String _normalizeHex(String input) => input.replaceAll(RegExp(r'\s'), '');
}
