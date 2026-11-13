import 'package:bb_mobile/core/wallet/domain/wallet_mutation_guard.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_account_files_port.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/sp_session_guard.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_secret_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/scan_sp_wallet_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:secrets/secrets.dart' show Secret;

/// Orchestrates SP wallet creation for the setup flow: gate on superuser +
/// dev mode, block a double setup, clear any stale revoked state, then create
/// the on-disk account.
class CreateSpWalletUsecase {
  final GetSpSecretUsecase _getSpSecretUsecase;
  final SettingsRepository _settingsRepository;
  final SpAccountRepository _repository;
  final WalletMutationGuard _walletMutationGuard;
  final SpSessionGuard _guard;
  final SpAccountFilesPort _files;
  final SpBackendConfigRepository _configRepository;
  final ScanSpWalletUsecase _scanSpWalletUsecase;

  CreateSpWalletUsecase({
    required this._getSpSecretUsecase,
    required this._settingsRepository,
    required this._repository,
    required this._walletMutationGuard,
    required this._guard,
    required this._files,
    required this._configRepository,
    required this._scanSpWalletUsecase,
  });

  /// [scanFromNow] seeds the scan cursor at the current tip so the wallet skips
  /// its history. Leave it false to let the user pick a start height instead.
  @useResult
  Future<Result<void, SpFailure>> execute({
    required BitcoinNetwork network,
    required String walletId,
    required String blindbitUrl,
    required String electrumUrl,
    required bool scanFromNow,
  }) => _guard.exclusive(
    () => _walletMutationGuard.exclusive(
      () => _execute(
        network: network,
        walletId: walletId,
        blindbitUrl: blindbitUrl,
        electrumUrl: electrumUrl,
        scanFromNow: scanFromNow,
      ),
    ),
  );

  Future<Result<void, SpFailure>> _execute({
    required BitcoinNetwork network,
    required String walletId,
    required String blindbitUrl,
    required String electrumUrl,
    required bool scanFromNow,
  }) async {
    // Outer boundary: any Exception from the settings/secret/sentinel/save reads
    // becomes an Err so execute() is total.
    try {
      final settings = await _settingsRepository.fetch();
      if (settings.isSuperuser != true) {
        return const Err(SpRequiresSuperuser());
      }
      if (settings.isDevModeEnabled != true) {
        return const Err(SpRequiresDevMode());
      }

      final Secret secret;
      final SpSourceBinding source;
      switch (await _getSpSecretUsecase.resolve(network, walletId: walletId)) {
        case Ok(:final value):
          secret = value.secret;
          source = value.binding;
        case Err(:final failure):
          return Err(failure);
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
      switch (await _configRepository.fetch()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          storedConfig = value;
      }
      if (!hasSentinel && storedConfig != null) {
        return const Err(SpAlreadySetUp('SP wallet already set up'));
      }

      switch (await _files.hasLegacyData()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: true):
          return const Err(SpLegacySourceUnverified());
        case Ok():
          break;
      }

      // A leftover backup must never be adopted under a different new source,
      // including after a partially completed revoke.
      switch (await _files.hasOrphanBackups()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: true):
          return const Err(SpRecoveryRequired());
        case Ok():
          break;
      }

      // A directory without a config may hold an older or interrupted account.
      // Never open it with a newly selected secret or overwrite its history.
      if (!hasSentinel && storedConfig == null) {
        switch (await _files.accountDirExists()) {
          case Err(:final failure):
            return Err(failure);
          case Ok(value: true):
            return const Err(SpRecoveryRequired());
          case Ok():
            break;
        }
      }

      // A revoked but incompletely removed account must be cleared by retrying
      // revoke, never by starting a new setup over the old source.
      if (hasSentinel) return const Err(SpRecoveryRequired());

      // Validated here, before the FFI create, so the same checked config is
      // used to create and then saved. `parse` reports a broken invariant as
      // Err: the constructor throws an ArgumentError, which is an Error and so
      // would escape the `on Exception` boundary below.
      final SpBackendConfig config;
      switch (SpBackendConfig.parse(
        network: network,
        source: source,
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
      if (await _files.createAccountDir(config) case Err(:final failure)) {
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
        // Keep the pending marker and config: a native failure may have left
        // an undisclosed handle or partially written account files.
        return failure is SpSourceMismatch
            ? Err(failure)
            : const Err(SpRecoveryRequired());
      }
      // Set before returning so a redirect in the same turn as the navigation
      // that follows already sees the wallet as set up.
      _configRepository.setIsSetUpNow(isSetUp: true);
      if (scanFromNow) await _seedScanCursor();
      return const Ok(null);
    } on Exception catch (_) {
      // Fixed text: this block opens the account from the secret, so the
      // caught exception never reaches a log.
      return const Err(SpUnexpected('SP wallet create failed'));
    }
  }

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
