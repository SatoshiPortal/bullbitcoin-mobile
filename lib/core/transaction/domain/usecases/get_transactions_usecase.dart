import 'package:bb_mobile/core/transaction/domain/entities/transaction.dart';
import 'package:bb_mobile/core/transaction/domain/repositories/transaction_repository.dart';

class GetTransactionsUsecase {
  final TransactionRepository _transactionRepository;

  GetTransactionsUsecase({
    required TransactionRepository transactionRepository,
  }) : _transactionRepository = transactionRepository;

  Future<List<Transaction>> execute({String? walletId}) async {
    try {
      final transactions = await _transactionRepository.getTransactions(
        walletId: walletId,
      );
      return transactions;
    } catch (e) {
      throw GetTransactionsException(e.toString());
    }
  }
}

class GetTransactionsException implements Exception {
  final String message;

  GetTransactionsException(this.message);
}
