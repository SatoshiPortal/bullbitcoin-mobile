import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap_master_key_info.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

/// Reads the swap master key (the "swap mnemonic") for the current
/// environment's default bitcoin wallet, for display in the seed viewer.
/// Returns null when no default bitcoin wallet exists or no swap key has been
/// derived yet. Mirrors the wallet-resolution of [EnsureSwapMasterKeyUsecase]
/// so it reads exactly the key that creation/restore use.
class GetSwapMasterKeyUsecase {
  final SettingsRepository _settingsRepository;
  final WalletRepository _walletRepository;
  final BoltzSwapRepository _swapRepository;

  GetSwapMasterKeyUsecase({
    required this._settingsRepository,
    required this._walletRepository,
    required this._swapRepository,
  });

  Future<SwapMasterKeyInfo?> execute() async {
    final settings = await _settingsRepository.fetch();
    final wallets = await _walletRepository.getWallets(
      onlyDefaults: true,
      onlyBitcoin: true,
      environment: settings.environment,
    );
    if (wallets.isEmpty) return null;
    final fingerprint = wallets.first.masterFingerprint;
    if (fingerprint.isEmpty) return null;
    return _swapRepository.getSwapMasterKeyInfo(walletFingerprint: fingerprint);
  }
}
