import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class UpdateWalletBehaviorUsecase {
  final WalletRepository _walletRepository;

  UpdateWalletBehaviorUsecase({required this._walletRepository});

  Future<void> execute({
    required String walletId,
    bool? hideOnHome,
    bool? autoSweepEnabled,
  }) {
    return _walletRepository.updateWalletBehavior(
      walletId: walletId,
      hideOnHome: hideOnHome,
      autoSweepEnabled: autoSweepEnabled,
    );
  }
}
