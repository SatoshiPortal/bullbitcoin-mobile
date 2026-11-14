import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';

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
