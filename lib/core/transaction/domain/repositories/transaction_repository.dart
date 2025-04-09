import 'package:bb_mobile/core/transaction/domain/entities/transaction.dart';

abstract class TransactionRepository {
  Stream<WalletTransaction> get transactions;
  Future<List<WalletTransaction>> getTransactions({
    String? walletId,
  });
  Future<WalletTransaction> getTransaction(
    String txId, {
    required String walletId,
  });
}
