import 'package:primitives/primitives.dart';

import '../transaction_failure.dart';

import 'package:preferences/preferences.dart';
import 'package:transactions/src/domain/entities/wallet_transaction.dart';

abstract interface class WalletTransactionRepository {
  Future<Result<List<WalletTransaction>, TransactionFailure>>
  getWalletTransactions({
    String? txId,
    String? walletId,
    String? toAddress,
    Environment? environment,
    bool sync = false,
  });
  Future<Result<WalletTransaction?, TransactionFailure>> getWalletTransaction(
    String txId, {
    required String walletId,
    bool sync = false,
  });
}
