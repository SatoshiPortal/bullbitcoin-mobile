import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';

class PollReceiveWalletUsecase {
  final WalletFacade _wallet;

  const PollReceiveWalletUsecase(this._wallet);

  Future<void> execute(String walletId, {required bool Function() isActive}) =>
      _wallet.pollWallet(walletId, isActive: isActive);
}
