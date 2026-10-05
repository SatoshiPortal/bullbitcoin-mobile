import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_account_files_port.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_key_material.dart';
import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/sp_session_guard.dart';
import 'package:meta/meta.dart';

class RecreateSpWalletUsecase {
  final GetDefaultSeedUsecase _getDefaultSeedUsecase;
  final SpAccountRepository _repository;
  final SpAccountFilesPort _files;
  final SpBackendConfigRepository _configRepository;
  final EnsureSpSessionUsecase _ensureSpSessionUsecase;
  final SpSessionGuard _guard;

  RecreateSpWalletUsecase({
    required this._getDefaultSeedUsecase,
    required this._repository,
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
  }) => _guard.exclusive(() async {
    // Outer boundary: any Exception from the seed/dispose/backup/discardBackup
    // work becomes an Err so execute() is total. A non-mnemonic seed still
    // throws a StateError (a programmer bug, never caught) per
    // spMnemonicFromSeed.
    try {
      final seed = await _getDefaultSeedUsecase.execute();
      final mnemonic = spMnemonicFromSeed(seed);

      // Read before the teardown bracket, so a failed read aborts with nothing
      // to unwind. It must not read as "no previous config": the rollback would
      // then delete the stored one instead of restoring it.
      final SpBackendConfig? previousConfig;
      switch (await _configRepository.fetchOrNull()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          previousConfig = value;
      }

      // Validated before the teardown bracket too, for the same reason: a bad
      // config must abort while the session is still up and the account dir is
      // still in place. `parse` reports it as Err, where the constructor would
      // throw an ArgumentError past the `on Exception` boundary below.
      final SpBackendConfig config;
      switch (SpBackendConfig.parse(
        network: network,
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
        if (await _files.backupAccountDir() case Err(:final failure)) {
          return Err(failure);
        }

        // Persist the config BEFORE the FFI create so a successful create
        // always implies a matching saved config. A save failure happens with
        // no live session yet, so there is nothing to roll back.
        final saved = await _configRepository.save(config);
        if (saved case Err(:final failure)) return Err(failure);
        final created = await _repository.createFromMnemonic(
          network: config.network,
          mnemonic: mnemonic,
          blindbitUrl: config.blindbitUrl,
          electrumUrl: config.electrumUrl,
          fetchConcurrencyFactor: config.fetchConcurrencyFactor,
          matchConcurrencyFactor: config.matchConcurrencyFactor,
        );
        if (created case Err(:final failure)) {
          await _rollback(previousConfig);
          // Forwarded as-is: no SP failure text is derived from the mnemonic.
          return Err(failure);
        }

        // Now reachable: the datasource reports a failed delete instead of
        // swallowing it. Not fatal, the recreated wallet is already live and
        // the leftover dir is swept on the next revoke.
        if (await _files.discardBackup() case Err(:final failure)) {
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
      // Fixed text: this block reads the seed and derives the mnemonic, so the
      // caught exception never reaches a log.
      return const Err(SpUnexpected('SP wallet recreate failed'));
    }
  });

  /// Undo a failed recreate: drop the half-built session, restore the backed-up
  /// account dir, revert the persisted config, and re-establish the previous
  /// session when its dir came back. Best effort throughout; the create failure
  /// is what the caller reports.
  Future<void> _rollback(SpBackendConfig? previousConfig) async {
    if (await _repository.dispose() case Err(:final failure)) {
      log.warning(
        'RecreateSpWalletUsecase: rollback dispose failed: '
        '${failure.logMessage}',
      );
    }
    final restored = switch (await _files.restoreAccountDir()) {
      Ok(:final value) => value,
      Err(:final failure) => () {
        log.warning(
          'RecreateSpWalletUsecase: rollback restore failed: '
          '${failure.logMessage}',
        );
        return false;
      }(),
    };
    // Always revert the config so a failed recreate never leaves the new
    // (unusable) config persisted: re-save the previous one if there was one,
    // else delete so the wallet reverts to not-set-up.
    final reverted = previousConfig != null
        ? await _configRepository.save(previousConfig)
        : await _configRepository.delete();
    if (reverted case Err(:final failure)) {
      log.warning(
        'RecreateSpWalletUsecase: rollback config revert failed: '
        '${failure.logMessage}',
      );
    }
    // Re-establish the previous session only when its dir was restored. The
    // teardown bracket stays held: clearing it here would unblock every other
    // establishment across the awaits below, and with a concurrent revoke it
    // would also decrement a depth this frame does not own.
    if (restored) {
      if (await _ensureSpSessionUsecase.execute(allowDuringTeardown: true)
          case Err(:final failure)) {
        log.warning(
          'RecreateSpWalletUsecase: rollback re-establish failed: '
          '${failure.logMessage}',
        );
      }
    }
  }
}
