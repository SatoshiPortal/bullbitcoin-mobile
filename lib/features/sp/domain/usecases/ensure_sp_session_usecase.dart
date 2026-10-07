import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_account_files_port.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_scan_key_usecase.dart';
import 'package:secrets/secrets.dart' show SilentPaymentDescriptors;
import 'package:bb_mobile/features/sp/domain/sp_session_guard.dart';

/// Establishes the live SP session, reconstructing it via `createFromScanKey`
/// from the persisted backend config (the FFI create path never writes a
/// reloadable config file, so `SpAccount.load` cannot be used).
///
/// Returns null when the wallet is not set up: a `.revoked` sentinel is present
/// or no backend config is stored. Reconstruction reuses the on-disk sqlite
/// stores, so balance and history survive.
///
/// Registered as a singleton so the in-flight guard serializes establishment:
/// concurrent callers (the SP shell `load()` and the wallet-side refresh on cold
/// start) share one `createFromScanKey` instead of racing two live sessions.
class EnsureSpSessionUsecase {
  final SpAccountRepository _repository;
  final SpAccountFilesPort _files;
  final SpBackendConfigRepository _configRepository;
  final GetSpScanKeyUsecase _getSpScanKeyUsecase;
  final SpSessionGuard _guard;

  EnsureSpSessionUsecase({
    required this._repository,
    required this._files,
    required this._configRepository,
    required this._getSpScanKeyUsecase,
    required this._guard,
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
  }) {
    // Rollback already owns the non-reentrant guard. It must not join a
    // public establishment queued behind that same owner either.
    if (allowDuringTeardown) return _execute(allowDuringTeardown: true);
    if (_repository.teardownInProgress) return Future.value(const Ok(null));
    return _inFlight ??= _guard
        .exclusive(() => _execute(allowDuringTeardown: false))
        .whenComplete(() {
          _inFlight = null;
        });
  }

  Future<Result<SpWallet?, SpFailure>> _execute({
    required bool allowDuringTeardown,
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
    return _establish(allowDuringTeardown: allowDuringTeardown);
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

    final SilentPaymentDescriptors scanKey;
    switch (await _getSpScanKeyUsecase.execute(network: config.network)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        scanKey = value;
    }

    // Re-check right before creating: a revoke/recreate may have begun teardown
    // during the awaits above, and creating now would race a live session.
    if (!allowDuringTeardown && _repository.teardownInProgress) {
      return const Ok(null);
    }

    final created = await _repository.createFromScanKey(
      scanKey: scanKey,
      blindbitUrl: config.blindbitUrl,
      electrumUrl: config.electrumUrl,
      fetchConcurrencyFactor: config.fetchConcurrencyFactor,
      matchConcurrencyFactor: config.matchConcurrencyFactor,
    );
    if (created case Err(:final failure)) return Err(failure);
    return _repository.snapshot();
  }
}
