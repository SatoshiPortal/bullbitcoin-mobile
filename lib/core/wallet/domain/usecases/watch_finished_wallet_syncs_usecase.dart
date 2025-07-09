import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class WatchFinishedWalletSyncsUsecase {
  final WalletRepository _walletRepository;

  WatchFinishedWalletSyncsUsecase({required WalletRepository walletRepository})
    : _walletRepository = walletRepository;

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

class WatchFinishedWalletSyncsException implements Exception {
  final String message;

  WatchFinishedWalletSyncsException(this.message);
}
