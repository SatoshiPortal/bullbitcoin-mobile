import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_key_material.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';

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
  final SpBackendConfigRepository _configRepository;
  final GetDefaultSeedUsecase _getDefaultSeedUsecase;

  EnsureSpSessionUsecase({
    required this._repository,
    required this._configRepository,
    required this._getDefaultSeedUsecase,
  });

  Future<SpWallet?>? _inFlight;

  Future<SpWallet?> execute() async {
    // A recreate/revoke is disposing (and maybe re-establishing) the session;
    // do not start a competing establishment while it runs.
    if (_repository.teardownInProgress) return null;
    if (_repository.hasSession) {
      // A live session can outlive a revoke by a beat (the revoke writes the
      // sentinel before disposing). Re-check it so a zombie session is torn
      // down instead of serving a revoked wallet until app restart.
      if (await _repository.hasRevokedSentinel()) {
        await _repository.dispose();
        return null;
      }
      return _repository.snapshot();
    }
    return _inFlight ??= _establish().whenComplete(() => _inFlight = null);
  }

  Future<SpWallet?> _establish() async {
    if (_repository.teardownInProgress) return null;
    // A `.revoked` sentinel means a prior revoke deleted (or tried to) this
    // wallet; never reload it.
    if (await _repository.hasRevokedSentinel()) return null;

    // A corrupt/unknown-network config is treated as "not set up" here (the
    // user can re-run setup, which overwrites it); the repo already logs the
    // parse failure via the Err's logMessage.
    final config = (await _configRepository.fetch()).fold(
      (config) => config,
      (_) => null,
    );
    if (config == null) return null;

    final seed = await _getDefaultSeedUsecase.execute();
    final mnemonic = spMnemonicFromSeed(seed);

    await _repository.createFromMnemonic(
      network: config.network,
      mnemonic: mnemonic,
      blindbitUrl: config.blindbitUrl,
      electrumUrl: config.electrumUrl,
    );
    return _repository.snapshot();
  }
}
