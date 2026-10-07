import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_account_files_port.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_scan_key_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/scan_sp_wallet_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/features/sp/domain/sp_session_guard.dart';
import 'package:secrets/secrets.dart' show SilentPaymentDescriptors;

/// Orchestrates SP wallet creation for the setup flow: gate on superuser +
/// dev mode, block a double setup, clear any stale revoked state, then create
/// the on-disk account.
class CreateSpWalletUsecase {
  final GetSpScanKeyUsecase _getSpScanKeyUsecase;
  final SettingsRepository _settingsRepository;
  final SpAccountRepository _repository;
  final SpAccountFilesPort _files;
  final SpBackendConfigRepository _configRepository;
  final ScanSpWalletUsecase _scanSpWalletUsecase;
  final SpSessionGuard _guard;

  CreateSpWalletUsecase({
    required this._getSpScanKeyUsecase,
    required this._settingsRepository,
    required this._repository,
    required this._files,
    required this._configRepository,
    required this._scanSpWalletUsecase,
    required this._guard,
  });

  /// [scanFromNow] seeds the scan cursor at the current tip so the wallet skips
  /// its history. Leave it false to let the user pick a start height instead.
  @useResult
  Future<Result<void, SpFailure>> execute({
    required BitcoinNetwork network,
    required String blindbitUrl,
    required String electrumUrl,
    required bool scanFromNow,
  }) => _guard.exclusive(() async {
    // Outer boundary: any Exception from the settings/sentinel/save reads
    // becomes an Err so execute() is total.
    try {
      final settings = await _settingsRepository.fetch();
      if (settings.isSuperuser != true) {
        return const Err(SpRequiresSuperuser());
      }
      if (settings.isDevModeEnabled != true) {
        return const Err(SpRequiresDevMode());
      }

      // Derived before any side effect, so a missing default wallet or a
      // locked keystore aborts with nothing to undo.
      final SilentPaymentDescriptors scanKey;
      switch (await _getSpScanKeyUsecase.execute(network: network)) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          scanKey = value;
      }

      final bool hasSentinel;
      switch (await _files.hasRevokedSentinel()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          hasSentinel = value;
      }

      // A stored config with no revoke sentinel means the wallet is already set
      // up; refuse a second setup. A failed read is Err, like the sentinel read
      // above: reading it as "no wallet" would run this create over a live one.
      final SpBackendConfig? storedConfig;
      switch (await _configRepository.fetchOrNull()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          storedConfig = value;
      }
      if (!hasSentinel && storedConfig != null) {
        return const Err(SpAlreadySetUp('SP wallet already set up'));
      }

      // Clear stale revoked state left by a failed revoke delete: the dir may
      // still hold an account.sqlite + sentinel. Leaving it would make setup
      // "succeed" yet be unreachable, since loads are blocked while the
      // sentinel exists.
      if (hasSentinel) {
        if (await _files.deleteAccountDir() case Err(:final failure)) {
          return Err(
            SpSetupCleanupFailed(
              'Failed to clear stale SP wallet state: ${failure.logMessage}',
            ),
          );
        }
      }

      // Validated here, before the FFI create, so the same checked config is
      // used to create and then saved. `parse` reports a broken invariant as
      // Err: the constructor throws an ArgumentError, which is an Error and so
      // would escape the `on Exception` boundary below.
      final SpBackendConfig config;
      switch (SpBackendConfig.parse(
        network: network,
        blindbitUrl: blindbitUrl,
        electrumUrl: electrumUrl,
      )) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          config = value;
      }
      // Persist the backend config BEFORE the FFI create so a successful create
      // always implies a matching saved config (the FFI create path writes no
      // reloadable config file). Mirrors recreate.
      if (await _configRepository.save(config) case Err(:final failure)) {
        return Err(failure);
      }
      final created = await _repository.createFromScanKey(
        scanKey: scanKey,
        blindbitUrl: config.blindbitUrl,
        electrumUrl: config.electrumUrl,
        fetchConcurrencyFactor: config.fetchConcurrencyFactor,
        matchConcurrencyFactor: config.matchConcurrencyFactor,
      );
      if (created case Err(:final failure)) {
        // Roll the config back so a failed first-time setup leaves no persisted
        // config. Create is always a fresh setup with no prior config, so
        // delete reverts to not-set-up. Without it, the guard (no sentinel +
        // stored config) would wedge the next attempt behind SpAlreadySetUp.
        // Best effort: the create failure is what the caller reports.
        if (await _configRepository.delete() case Err(
          failure: final deleteFailure,
        )) {
          log.warning(
            'CreateSpWalletUsecase: config rollback delete failed: '
            '${deleteFailure.logMessage}',
          );
        }
        // Forwarded as-is: no SP failure text is derived from the scan key.
        return Err(failure);
      }
      // Set before returning so a redirect in the same turn as the navigation
      // that follows already sees the wallet as set up.
      _configRepository.setIsSetUpNow(isSetUp: true);
      if (scanFromNow) await _seedScanCursor();
      return const Ok(null);
    } on Exception catch (_) {
      // Fixed text: this block handles the scan key, so the caught exception
      // never reaches a log.
      return const Err(SpUnexpected('SP wallet create failed'));
    }
  });

  /// Scan tip to tip, which covers roughly no blocks and exists only to record
  /// a cursor. A failure leaves the cursor unset, which just means the user
  /// starts the first scan by hand, so it must not fail a setup whose wallet
  /// and config already exist.
  Future<void> _seedScanCursor() async {
    try {
      final int tip;
      switch (_repository.currentBlockHeight()) {
        case Err(:final failure):
          log.warning('SP scan cursor seed failed: ${failure.logMessage}');
          return;
        case Ok(:final value):
          tip = value;
      }
      final result = await _scanSpWalletUsecase.execute(startHeight: tip);
      if (result case Err(:final failure)) {
        log.warning('SP scan cursor seed failed: ${failure.logMessage}');
      }
    } catch (e) {
      log.warning('SP scan cursor seed failed: $e');
    }
  }
}
