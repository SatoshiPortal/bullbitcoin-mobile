import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class CheckWalletSyncingUsecase {
  final WalletRepository _walletRepository;

  CheckWalletSyncingUsecase({required WalletRepository walletRepository})
    : _walletRepository = walletRepository;

  bool execute({String? walletId}) {
    try {
      final isWalletSyncing = _walletRepository.isWalletSyncing(
        walletId: walletId,
      );

      return isWalletSyncing;
    } catch (e) {
      throw CheckAnyWalletSyncingException('$e');
    }
  }
}

class CheckAnyWalletSyncingException implements Exception {
  final String message;

  CheckAnyWalletSyncingException(this.message);
}
