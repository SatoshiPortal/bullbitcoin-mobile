import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class CheckAnyWalletSyncingUsecase {
  final WalletRepository _walletRepository;

  CheckAnyWalletSyncingUsecase({
    required WalletRepository walletRepository,
  }) : _walletRepository = walletRepository;

  bool execute() {
    try {
      final isAnyWalletSyncing = _walletRepository.isAnyWalletSyncing;

      return isAnyWalletSyncing;
    } catch (e) {
      throw CheckAnyWalletSyncingException('$e');
    }
  }
}

class CheckAnyWalletSyncingException implements Exception {
  final String message;

  CheckAnyWalletSyncingException(this.message);
}
