import 'package:primitives/primitives.dart';
import 'package:wallet/wallet.dart';

class WatchFinishedWalletSyncsUsecase {
  final WalletRepository _walletRepository;

  WatchFinishedWalletSyncsUsecase({required this._walletRepository});

  Stream<Wallet> execute({String? walletId}) {
    try {
      if (walletId != null) {
        return _walletRepository.walletSyncFinishedStream.where(
          (wallet) => wallet.id == walletId,
        );
      } else {
        return _walletRepository.walletSyncFinishedStream;
      }
    } catch (e) {
      throw WatchFinishedWalletSyncsException(e.toString());
    }
  }
}

class WatchFinishedWalletSyncsException extends BullException {
  WatchFinishedWalletSyncsException(super.message);
}
