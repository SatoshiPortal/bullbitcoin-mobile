import 'package:bb_mobile/core/wallet/domain/entity/balance.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_manager_service.dart';

/// Use case to retrieve the balance of a specific wallet
class GetBalanceUsecase {
  final WalletManagerService _walletManagerService;

  const GetBalanceUsecase({
    required WalletManagerService walletManagerService,
  }) : _walletManagerService = walletManagerService;

  Future<Balance> execute({
    required String walletId,
  }) async {
    final balance = await _walletManagerService.getBalance(walletId: walletId);
    return balance;
  }
}
