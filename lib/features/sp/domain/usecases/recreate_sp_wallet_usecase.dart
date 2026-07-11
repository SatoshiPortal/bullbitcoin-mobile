import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_key_material.dart';
import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';

class RecreateSpWalletUsecase {
  final GetDefaultSeedUsecase _getDefaultSeedUsecase;
  final SpAccountRepository _repository;
  final SpBackendConfigRepository _configRepository;
  final EnsureSpSessionUsecase _ensureSpSessionUsecase;

  RecreateSpWalletUsecase({
    required this._getDefaultSeedUsecase,
    required this._repository,
    required this._configRepository,
    required this._ensureSpSessionUsecase,
  });

  @useResult
  Future<Result<void, SpFailure>> execute({
    required SpNetwork network,
    required String blindbitUrl,
    required String electrumUrl,
  }) async {
    final seed = await _getDefaultSeedUsecase.execute();
    final mnemonic = spMnemonicFromSeed(seed);

    final previousConfig = (await _configRepository.fetch()).fold(
      (config) => config,
      (_) => null,
    );

    // Suppress the cubit self-heal for the whole dispose+create window so it
    // cannot re-establish (and double-create) the session mid-teardown.
    _repository.beginTeardown();
    try {
      await _repository.dispose();

      // Move the current account dir aside so a failed create can roll back.
      await _repository.backupAccountDir();

      try {
        // Persist the config BEFORE the FFI create so a successful create
        // always implies a matching saved config. A save failure happens with
        // no live session yet, so there is nothing to roll back.
        await _configRepository.save(
          SpBackendConfig(
            network: network,
            blindbitUrl: blindbitUrl,
            electrumUrl: electrumUrl,
          ),
        );
        await _repository.createFromMnemonic(
          network: network,
          mnemonic: mnemonic,
          blindbitUrl: blindbitUrl,
          electrumUrl: electrumUrl,
        );
      } catch (e) {
        await _repository.dispose();
        final restored = await _repository.restoreAccountDir();
        if (restored) {
          // Restore the previous config so the session reconstructed from the
          // restored directory targets its original backend.
          if (previousConfig != null) {
            await _configRepository.save(previousConfig);
          }
          // Clear teardown before restoring so EnsureSpSessionUsecase will
          // re-establish the previous session instead of refusing.
          _repository.endTeardown();
          await _ensureSpSessionUsecase.execute();
        }
        return Err(SpUnexpected('SP wallet recreate failed: $e'));
      }

      await _repository.discardBackup();
      return const Ok(null);
    } finally {
      _repository.endTeardown();
    }
  }
}
