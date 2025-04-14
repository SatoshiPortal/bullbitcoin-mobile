import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/wallet_transaction/domain/entities/wallet_transaction.dart';

abstract class WalletTransactionRepository {
  //Stream<WalletTransaction> get walletTransactions;
  Future<List<WalletTransaction>> getWalletTransactions({
    String? origin,
    String? toAddress,
    Environment? environment,
    bool sync = false,
  });
  Future<WalletTransaction> getWalletTransaction(
    String txId, {
    required String origin,
    bool sync = false,
  });
}
