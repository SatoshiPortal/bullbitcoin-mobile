import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';

/// Pull-to-refresh of one wallet's coins: a screen sync of that wallet through
/// the wallet owner, then the caller reloads its local coins.
class RefreshCoinsUsecase {
  final WalletFacade _wallet;

  RefreshCoinsUsecase(this._wallet);

  Future<void> execute({required String walletId}) async {
    try {
      await _wallet.pollWallet(walletId, isActive: () => true);
    } on Exception {
      // The wallet owner records sync failures itself. Let the caller reload
      // local coins so pull-to-refresh still settles cleanly.
    }
  }
}
