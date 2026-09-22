import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap_master_key_info.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

import 'package:bb_mobile/core/wallet/domain/wallet_failure_bridge.dart';
import 'package:bb_mobile/core/utils/result.dart';

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
    final wallets = switch (await _walletRepository.getWallets(
      onlyDefaults: true,
      onlyBitcoin: true,
      environment: settings.environment,
    )) {
      Ok(:final value) => value,
      // TODO(#1895): core/swaps has no failure family yet. Map WalletFailure into
      // it instead of throwing once it does.
      Err(:final failure) => throw WalletFailureException(failure),
    };
    if (wallets.isEmpty) return null;
    final fingerprint = wallets.first.masterFingerprint;
    if (fingerprint.isEmpty) return null;
    return _swapRepository.getSwapMasterKeyInfo(walletFingerprint: fingerprint);
  }
}
