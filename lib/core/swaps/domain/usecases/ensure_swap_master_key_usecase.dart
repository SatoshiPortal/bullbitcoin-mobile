import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

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
  final SeedRepository _seedRepository;
  final BoltzSwapRepository _swapRepository;

  EnsureSwapMasterKeyUsecase({
    required this._settingsRepository,
    required this._walletRepository,
    required this._seedRepository,
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
    final seed = await _seedRepository.get(fingerprint);
    if (seed is! MnemonicSeed) {
      return;
    }

    await _swapRepository.ensureSwapMasterKey(
      mnemonic: seed.mnemonicWords.join(' '),
      walletFingerprint: fingerprint,
    );
    log.fine('SWAP_KEY: swap master key ready for wallet $fingerprint');
  }
}
