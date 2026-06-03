import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class ApplyWalletBehaviorDefaultsUsecase {
  final WalletRepository _walletRepository;

  ApplyWalletBehaviorDefaultsUsecase({required this._walletRepository});

  Future<void> execute({
    required String walletId,
    bool? hideOnHome,
    bool? autoSweepEnabled,
  }) {
    return _walletRepository.applyWalletBehaviorDefaultsIfMissing(
      walletId: walletId,
      hideOnHome: hideOnHome,
      autoSweepEnabled: autoSweepEnabled,
    );
  }
}
