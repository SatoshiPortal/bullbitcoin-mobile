import 'package:bb_mobile/core/transaction/domain/entities/transaction.dart';

abstract class TransactionRepository {
  Stream<Transaction> get transactions;
  Future<List<Transaction>> getTransactions({
    String? walletId,
  });
  Future<Transaction> getTransaction(String txId, {required String walletId});
}
