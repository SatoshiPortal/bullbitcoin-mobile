import 'package:bb_mobile/core_deprecated/errors/bull_exception.dart';
import 'package:bb_mobile/core_deprecated/wallet/data/repositories/wallet_repository.dart';

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

class CheckAnyWalletSyncingException extends BullException {
  CheckAnyWalletSyncingException(super.message);
}
