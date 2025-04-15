import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class GetWalletUsecase {
  final WalletRepository _wallet;

  GetWalletUsecase({
    required WalletRepository walletRepository,
  }) : _wallet = walletRepository;

  Future<Wallet> execute(String origin, {bool sync = false}) async {
    try {
      final wallet = await _wallet.getWallet(
        origin,
        sync: sync,
      );

      return wallet;
    } catch (e) {
      throw GetWalletException('$e');
    }
  }
}

class GetWalletException implements Exception {
  final String message;

  GetWalletException(this.message);
}
