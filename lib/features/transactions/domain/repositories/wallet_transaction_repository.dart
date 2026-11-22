import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/transactions/domain/entities/wallet_transaction.dart';

abstract interface class WalletTransactionRepository {
  Future<List<WalletTransaction>> getWalletTransactions({
    String? txId,
    String? walletId,
    String? toAddress,
    Environment? environment,
    bool sync = false,
  });
  Future<WalletTransaction?> getWalletTransaction(
    String txId, {
    required String walletId,
    bool sync = false,
  });
}
