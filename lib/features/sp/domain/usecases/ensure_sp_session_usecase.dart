import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_account_files_port.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_key_material.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';

/// Establishes the live SP session, reconstructing it via `createFromMnemonic`
/// from the persisted backend config (the FFI create path never writes a
/// reloadable config file, so `SpAccount.load` cannot be used).
///
/// Returns null when the wallet is not set up: a `.revoked` sentinel is present
/// or no backend config is stored. Reconstruction reuses the on-disk sqlite
/// stores, so balance and history survive.
///
/// Registered as a singleton so the in-flight guard serializes establishment:
/// concurrent callers (the SP shell `load()` and the wallet-side refresh on cold
/// start) share one `createFromMnemonic` instead of racing two live sessions.
class EnsureSpSessionUsecase {
  final SpAccountRepository _repository;
  final SpAccountFilesPort _files;
  final SpBackendConfigRepository _configRepository;
  final GetDefaultSeedUsecase _getDefaultSeedUsecase;

  EnsureSpSessionUsecase({
    required this._repository,
    required this._files,
    required this._configRepository,
    required this._getDefaultSeedUsecase,
  });

  Future<Result<SpWallet?, SpFailure>>? _inFlight;

  /// `Ok(null)` when the wallet is not set up (revoked, no config, or a
  /// teardown is running); `Err` when a read or the establishment failed.
  ///
  /// [allowDuringTeardown] is for the one caller that runs *inside* a teardown
  /// it owns: a failed recreate rolling back has to re-establish the previous
  /// session while its own bracket is still held.
  Future<Result<SpWallet?, SpFailure>> execute({
    bool allowDuringTeardown = false,
  }) async {
    // A recreate/revoke is disposing (and maybe re-establishing) the session;
    // do not start a competing establishment while it runs.
    if (!allowDuringTeardown && _repository.teardownInProgress) {
      return const Ok(null);
    }
    if (_repository.hasSession) {
      // A live session can outlive a revoke by a beat (the revoke writes the
      // sentinel before disposing). Re-check it so a zombie session is torn
      // down instead of serving a revoked wallet until app restart.
      switch (await _files.hasRevokedSentinel()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: true):
          // A dispose failure leaves the zombie up; report it rather than
          // handing back a snapshot of a revoked wallet.
          if (await _repository.dispose() case Err(:final failure)) {
            return Err(failure);
          }
          return const Ok(null);
        case Ok():
          break;
      }
      return _repository.snapshot();
    }
    return _inFlight ??= _establish(allowDuringTeardown: allowDuringTeardown)
        .whenComplete(() {
          _inFlight = null;
        });
  }

  Future<Result<SpWallet?, SpFailure>> _establish({
    required bool allowDuringTeardown,
  }) async {
    if (!allowDuringTeardown && _repository.teardownInProgress) {
      return const Ok(null);
    }
    // A recreate that crashed between the backup and the create left no account
    // dir and a backup beside it; put it back before anything reads the dir, so
    // the wallet is recovered instead of re-created empty.
    if (await _files.adoptNewestBackup() case Err(:final failure)) {
      return Err(failure);
    }
    // A `.revoked` sentinel means a prior revoke deleted (or tried to) this
    // wallet; never reload it.
    switch (await _files.hasRevokedSentinel()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: true):
        return const Ok(null);
      case Ok():
        break;
    }

    final SpBackendConfig config;
    switch (await _configRepository.fetchOrNull()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final stored?):
        config = stored;
      case Ok():
        return const Ok(null);
    }

    final String mnemonic;
    try {
      mnemonic = spMnemonicFromSeed(await _getDefaultSeedUsecase.execute());
    } on Exception catch (_) {
      // Fixed text: this block reads the seed and derives the mnemonic, so the
      // caught exception never reaches a log.
      return const Err(SpUnexpected('SP session establish failed'));
    }

    // Re-check right before creating: a revoke/recreate may have begun teardown
    // during the awaits above, and creating now would race a live session.
    if (!allowDuringTeardown && _repository.teardownInProgress) {
      return const Ok(null);
    }

    final created = await _repository.createFromMnemonic(
      network: config.network,
      mnemonic: mnemonic,
      blindbitUrl: config.blindbitUrl,
      electrumUrl: config.electrumUrl,
      fetchConcurrencyFactor: config.fetchConcurrencyFactor,
      matchConcurrencyFactor: config.matchConcurrencyFactor,
    );
    if (created case Err(:final failure)) return Err(failure);
    return _repository.snapshot();
  }
}
