import 'package:primitives/primitives.dart';
import 'package:wallet/wallet.dart';

class WatchStartedWalletSyncsUsecase {
  final WalletRepository _walletRepository;

  WatchStartedWalletSyncsUsecase({required this._walletRepository});

  Stream<String> execute({String? walletId}) {
    try {
      if (walletId != null) {
        return _walletRepository.walletSyncStartedIdsStream.where(
          (startedWalletId) => startedWalletId == walletId,
        );
      } else {
        return _walletRepository.walletSyncStartedIdsStream;
      }
    } catch (e) {
      throw WatchStartedWalletSyncsException(e.toString());
    }
  }
}

class WatchStartedWalletSyncsException extends BullException {
  WatchStartedWalletSyncsException(super.message);
}
