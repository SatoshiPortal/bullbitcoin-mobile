import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class WatchStartedWalletSyncsUsecase {
  final WalletRepository _walletRepository;

  WatchStartedWalletSyncsUsecase({required WalletRepository walletRepository})
    : _walletRepository = walletRepository;

  Stream<Wallet> execute({String? walletId}) {
    try {
      if (walletId != null) {
        return _walletRepository.walletSyncStartedStream.where(
          (wallet) => wallet.id == walletId,
        );
      } else {
        return _walletRepository.walletSyncStartedStream;
      }
    } catch (e) {
      throw WatchStartedWalletSyncsException(e.toString());
    }
  }
}

class WatchStartedWalletSyncsException extends BullException {
  WatchStartedWalletSyncsException(super.message);
}
