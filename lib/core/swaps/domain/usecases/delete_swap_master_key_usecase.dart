import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

/// Deletes the swap master key (the "swap mnemonic") for the current
/// environment's default bitcoin wallet — a super-user action exposed in the
/// seed viewer. Removes the master key blob and its index counter from secure
/// storage; the next `ensureSwapMasterKey` re-derives it from the wallet seed
/// (useful for testing the create -> reinstall -> restore flow, which the iOS
/// keychain otherwise defeats by surviving an app reinstall).
class DeleteSwapMasterKeyUsecase {
  final SettingsRepository _settingsRepository;
  final WalletRepository _walletRepository;
  final BoltzSwapRepository _swapRepository;

  DeleteSwapMasterKeyUsecase({
    required this._settingsRepository,
    required this._walletRepository,
    required this._swapRepository,
  });

  Future<void> execute() async {
    final settings = await _settingsRepository.fetch();
    final wallets = await _walletRepository.getWallets(
      onlyDefaults: true,
      onlyBitcoin: true,
      environment: settings.environment,
    );
    if (wallets.isEmpty) return;
    final fingerprint = wallets.first.masterFingerprint;
    if (fingerprint.isEmpty) return;
    await _swapRepository.deleteSwapMasterKey(walletFingerprint: fingerprint);
  }
}
