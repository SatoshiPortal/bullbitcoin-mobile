import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class SyncWalletUsecase {
  final WalletRepository _wallet;

  SyncWalletUsecase({required WalletRepository walletRepository})
    : _wallet = walletRepository;

  Future<void> execute(Wallet wallet) async {
    try {
      await _wallet.sync(wallet);
    } catch (e) {
      throw SyncWalletException('$e');
    }
  }
}

class SyncWalletException extends BullException {
  SyncWalletException(super.message);
}
