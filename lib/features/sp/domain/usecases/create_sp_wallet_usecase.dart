import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/sp_key_material.dart';
import 'package:meta/meta.dart';

/// Orchestrates SP wallet creation for the setup flow: gate on superuser +
/// dev mode, block a double setup, clear any stale revoked state, then create
/// the on-disk account.
class CreateSpWalletUsecase {
  final GetDefaultSeedUsecase _getDefaultSeedUsecase;
  final SettingsRepository _settingsRepository;
  final SpAccountRepository _repository;
  final SpBackendConfigRepository _configRepository;

  CreateSpWalletUsecase({
    required this._getDefaultSeedUsecase,
    required this._settingsRepository,
    required this._repository,
    required this._configRepository,
  });

  @useResult
  Future<Result<void, SpFailure>> execute({
    required SpNetwork network,
    required String blindbitUrl,
    required String electrumUrl,
  }) async {
    // Outer boundary: any Exception from the settings/seed/sentinel/save reads
    // becomes an Err so execute() is total. A non-mnemonic seed still throws a
    // StateError (a programmer bug, never caught) per spMnemonicFromSeed.
    try {
      final settings = await _settingsRepository.fetch();
      if (settings.isSuperuser != true) {
        return const Err(SpRequiresSuperuser());
      }
      if (settings.isDevModeEnabled != true) {
        return const Err(SpRequiresDevMode());
      }

      final seed = await _getDefaultSeedUsecase.execute();
      final mnemonic = spMnemonicFromSeed(seed);

      final hasSentinel = await _repository.hasRevokedSentinel();

      // A stored config with no revoke sentinel means the wallet is already set
      // up; refuse a second setup. A corrupt config counts as absent (it will
      // be overwritten by this setup).
      final storedConfig = (await _configRepository.fetch()).fold(
        (config) => config,
        (_) => null,
      );
      if (!hasSentinel && storedConfig != null) {
        return const Err(SpAlreadySetUp('SP wallet already set up'));
      }

      // Clear stale revoked state left by a failed revoke delete: the dir may
      // still hold an account.sqlite + sentinel. Leaving it would make setup
      // "succeed" yet be unreachable, since loads are blocked while the
      // sentinel exists.
      if (hasSentinel) {
        try {
          await _repository.wipeStaleAccountDir();
        } catch (e) {
          return Err(
            SpSetupCleanupFailed('Failed to clear stale SP wallet state: $e'),
          );
        }
      }

      // Validates the URLs (non-empty) at construction; build it before the FFI
      // create so the same checked config is used to create and then saved.
      final config = SpBackendConfig(
        network: network,
        blindbitUrl: blindbitUrl,
        electrumUrl: electrumUrl,
      );
      // Persist the backend config BEFORE the FFI create so a successful create
      // always implies a matching saved config (the FFI create path writes no
      // reloadable config file). Mirrors recreate.
      await _configRepository.save(config);
      try {
        await _repository.createFromMnemonic(
          network: config.network,
          mnemonic: mnemonic,
          blindbitUrl: config.blindbitUrl,
          electrumUrl: config.electrumUrl,
        );
      } catch (e) {
        // Roll the config back so a failed first-time setup leaves no persisted
        // config. Create is always a fresh setup with no prior config, so
        // delete reverts to not-set-up. Without it, the guard (no sentinel +
        // stored config) would wedge the next attempt behind SpAlreadySetUp.
        // The delete runs inside the outer boundary, so a delete throw still
        // returns Err rather than escaping execute.
        await _configRepository.delete();
        return Err(SpUnexpected('SP wallet create failed: $e'));
      }
      return const Ok(null);
    } on Exception catch (e) {
      return Err(SpUnexpected('SP wallet create failed: $e'));
    }
  }
}
