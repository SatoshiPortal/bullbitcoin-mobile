import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:secrets/secrets.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Fingerprint;
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';

/// Derives and persists the swap master key from the default bitcoin wallet's
/// seed so it exists before any swap needs it. Run when wallets become ready
/// (on `WalletStarted`), which fires on every wallet-ready path: app startup,
/// onboarding, vault restore and mnemonic/watch-only import.
///
/// Skips silently when there is no default bitcoin wallet with a mnemonic
/// (watch-only / hardware-only / pre-onboarding), so it can never block the
/// wallet flow for those users.
class EnsureSwapMasterKeyUsecase {
  final SettingsRepository _settingsRepository;
  final WalletRepository _walletRepository;
  final Secrets _secrets;
  final BoltzSwapRepository _swapRepository;

  EnsureSwapMasterKeyUsecase({
    required this._settingsRepository,
    required this._walletRepository,
    required this._secrets,
    required this._swapRepository,
  });

  Future<void> execute() async {
    final settings = await _settingsRepository.fetch();
    final wallets = await _walletRepository.getWallets(
      onlyDefaults: true,
      onlyBitcoin: true,
      environment: settings.environment,
    );
    if (wallets.isEmpty) {
      return;
    }

    final fingerprint = wallets.first.masterFingerprint;

    // Bind the key for reads and skip the wallet-seed decryption entirely when
    // it already exists (the common warm-launch case). Only a genuine first
    // derive reads the mnemonic.
    if (await _swapRepository.swapMasterKeyReady(
      walletFingerprint: fingerprint,
    )) {
      return;
    }

    final secret = switch (await _secrets.fetch(Fingerprint(fingerprint))) {
      Ok(:final value) => value,
      Err() => null,
    };
    if (secret == null || !secret.info.isMnemonic) {
      return;
    }
    // Derived inside the package from the wallet's words; what comes back is the swap-scoped credential the swaps module stores and signs with from then on.
    final network = wallets.first.network.isMainnet
        ? BitcoinNetwork.mainnet
        : BitcoinNetwork.testnet;
    final key = switch (await secret.derive.swapKey(network: network)) {
      Ok(:final value) => value,
      Err(:final failure) => throw StateError(
        'swap key derivation failed: ${failure.runtimeType}',
      ),
    };
    await _swapRepository.storeSwapMasterKey(
      key: key,
      walletFingerprint: fingerprint,
    );
    log.fine('SWAP_KEY: swap master key derived for wallet $fingerprint');
  }
}
