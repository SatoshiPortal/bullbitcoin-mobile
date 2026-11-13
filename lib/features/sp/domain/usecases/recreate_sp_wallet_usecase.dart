import 'package:bb_mobile/core/wallet/domain/wallet_mutation_guard.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_account_files_port.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_secret_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/sp_session_guard.dart';
import 'package:meta/meta.dart';
import 'package:secrets/secrets.dart' show Secret;

class RecreateSpWalletUsecase {
  final GetSpSecretUsecase _getSpSecretUsecase;
  final SpAccountRepository _repository;
  final WalletMutationGuard _walletMutationGuard;
  final SpAccountFilesPort _files;
  final SpBackendConfigRepository _configRepository;
  final EnsureSpSessionUsecase _ensureSpSessionUsecase;
  final SpSessionGuard _guard;

  RecreateSpWalletUsecase({
    required this._getSpSecretUsecase,
    required this._repository,
    required this._walletMutationGuard,
    required this._files,
    required this._configRepository,
    required this._ensureSpSessionUsecase,
    required this._guard,
  });

  /// Runs under [SpSessionGuard] so a concurrent revoke (the SP settings delete,
  /// or turning developer mode off) cannot tear this session down mid-rebuild.
  @useResult
  Future<Result<void, SpFailure>> execute({
    required BitcoinNetwork network,
    required String blindbitUrl,
    required String electrumUrl,
    int fetchConcurrencyFactor = SpConfig.defaultFetchConcurrencyFactor,
    int matchConcurrencyFactor = SpConfig.defaultMatchConcurrencyFactor,
  }) => _guard.exclusive(
    () => _walletMutationGuard.exclusive(() async {
      // Outer boundary: any Exception from the secret/dispose/backup/discardBackup
      // work becomes an Err so execute() is total.
      try {
        // Read before the teardown bracket, so a failed read aborts with nothing
        // to unwind. It must not read as "no previous config": the rollback would
        // then delete the stored one instead of restoring it.
        final SpBackendConfig? previousConfig;
        switch (await _configRepository.fetch()) {
          case Err(:final failure):
            return Err(failure);
          case Ok(:final value):
            previousConfig = value;
        }

        final source = previousConfig?.source;
        if (previousConfig == null ||
            source == null ||
            previousConfig.network != network) {
          return const Err(
            SpConfigInvalid('SP source or network cannot change'),
          );
        }
        final Secret secret;
        switch (await _getSpSecretUsecase.resolve(
          network,
          walletId: source.walletId,
          expected: source,
        )) {
          case Ok(:final value):
            secret = value.secret;
          case Err(:final failure):
            return Err(failure);
        }

        // Validated before the teardown bracket too, for the same reason: a bad
        // config must abort while the session is still up and the account dir is
        // still in place. `parse` reports it as Err, where the constructor would
        // throw an ArgumentError past the `on Exception` boundary below.
        final SpBackendConfig config;
        switch (SpBackendConfig.parse(
          network: network,
          source: source,
          blindbitUrl: blindbitUrl,
          electrumUrl: electrumUrl,
          fetchConcurrencyFactor: fetchConcurrencyFactor,
          matchConcurrencyFactor: matchConcurrencyFactor,
        )) {
          case Err(:final failure):
            return Err(failure);
          case Ok(:final value):
            config = value;
        }

        // Suppress the cubit self-heal for the whole dispose+create window so it
        // cannot re-establish (and double-create) the session mid-teardown.
        _repository.beginTeardown();
        try {
          if (await _repository.dispose() case Err(:final failure)) {
            return Err(failure);
          }

          // Move the current account dir aside so a failed create can roll back.
          switch (await _files.backupAccountDir(previousConfig)) {
            case Err(:final failure):
              return Err(failure);
            case Ok(value: false):
              return const Err(SpRecoveryRequired());
            case Ok():
              break;
          }

          // Persist the config BEFORE the FFI create so a successful create
          // always implies a matching saved config. A save failure happens with
          // no live session yet, so there is nothing to roll back.
          final saved = await _configRepository.save(config);
          if (saved case Err(:final failure)) return Err(failure);
          if (await _files.createAccountDir(config) case Err(:final failure)) {
            await _rollback(previousConfig);
            return Err(failure);
          }
          final created = await _walletMutationGuard.withoutReentrance(
            () => _repository.createFromSecret(
              network: config.network,
              expectedConfig: config,
              secret: secret,
              blindbitUrl: config.blindbitUrl,
              electrumUrl: config.electrumUrl,
              fetchConcurrencyFactor: config.fetchConcurrencyFactor,
              matchConcurrencyFactor: config.matchConcurrencyFactor,
            ),
          );
          if (created case Err(:final failure)) {
            // Preserve the pending directory and backup; a native handle may
            // still be retained and neither directory is safe to delete.
            return Err(failure);
          }

          // Now reachable: the datasource reports a failed delete instead of
          // swallowing it. Not fatal, the recreated wallet is already live and
          // the leftover dir is swept on the next revoke.
          if (await _files.discardBackup(previousConfig) case Err(
            :final failure,
          )) {
            log.warning(
              'RecreateSpWalletUsecase: discard backup failed: '
              '${failure.logMessage}',
            );
          }
          return const Ok(null);
        } finally {
          _repository.endTeardown();
        }
      } on Exception catch (_) {
        // Fixed text: this block opens the account from the secret, so the
        // caught exception never reaches a log.
        return const Err(SpUnexpected('SP wallet recreate failed'));
      }
    }),
  );

  /// Restore only when teardown and identity checks succeed. Never delete a
  /// partial or mismatched directory to force rollback.
  Future<void> _rollback(SpBackendConfig previousConfig) async {
    if (await _repository.dispose() case Err()) return;
    final restored = await _files.restoreAccountDir(previousConfig);
    if (restored is! Ok<bool, SpFailure> || !restored.value) return;
    if (await _configRepository.save(previousConfig) case Err()) return;
    if (await _ensureSpSessionUsecase.execute(allowDuringTeardown: true)
        case Err()) {
      log.warning('SP rollback could not re-establish the previous session');
    }
  }
}
