import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class WatchWalletSyncsUsecase {
  final WalletRepository _walletRepository;

  WatchWalletSyncsUsecase({
    required WalletRepository walletRepository,
  }) : _walletRepository = walletRepository;

  Stream<String> execute({
    String? walletId,
  }) {
    try {
      if (walletId != null) {
        return _walletRepository.walletSyncedStream
            .where((id) => id == walletId);
      } else {
        return _walletRepository.walletSyncedStream;
      }
    } catch (e) {
      throw WatchWalletSyncsException(e.toString());
    }
  }
}

class WatchWalletSyncsException implements Exception {
  final String message;

  WatchWalletSyncsException(this.message);
}
