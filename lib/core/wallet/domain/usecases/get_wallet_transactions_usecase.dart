// TODO: Create a Transaction entity first
import 'package:bb_mobile/core/wallet/domain/entity/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_manager_service.dart';

class GetWalletTransactionsUsecase {
  final WalletManagerService _manager;

  GetWalletTransactionsUsecase({required WalletManagerService walletManager})
      : _manager = walletManager;

  Future<List<WalletTransaction>> execute(
    String walletId,
  ) async {
    return await _manager.getTransactions(
      walletId: walletId,
    );
  }
}
