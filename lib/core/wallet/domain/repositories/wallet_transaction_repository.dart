import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_transaction.dart';

abstract class WalletTransactionRepository {
  //Stream<WalletTransaction> get walletTransactions;
  Future<List<WalletTransaction>> getWalletTransactions({
    String? walletId,
    String? toAddress,
    Environment? environment,
    bool sync = false,
  });
  Future<WalletTransaction> getWalletTransaction(
    String txId, {
    required String walletId,
    bool sync = false,
  });
}
