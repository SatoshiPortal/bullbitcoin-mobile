import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class GetWalletUsecase {
  final WalletRepository _wallet;

  GetWalletUsecase({required WalletRepository walletRepository})
    : _wallet = walletRepository;

  Future<Wallet?> execute(String walletId, {bool sync = false}) async {
    try {
      final wallet = await _wallet.getWallet(walletId, sync: sync);

      return wallet;
    } catch (e) {
      throw GetWalletException('$e');
    }
  }
}

class GetWalletException extends BullException {
  GetWalletException(super.message);
}
