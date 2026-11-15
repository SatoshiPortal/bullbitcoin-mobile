import 'package:bb_mobile/features/transactions/domain/entities/explored_transaction.dart';
import 'package:bb_mobile/features/transactions/domain/repositories/transaction_explorer_repository.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Err, Result;

class GetExploredTransactionUsecase {
  final TransactionExplorerRepository _repository;

  const GetExploredTransactionUsecase({required this._repository});

  @useResult
  Future<Result<ExploredTransaction, TransactionFailure>> execute(
    String txid,
  ) async {
    final normalized = txid.trim().toLowerCase();
    if (!ExploredTransaction.isValidTxid(normalized)) {
      return const Err(TransactionExplorerInvalidTxidFailure());
    }
    return _repository.fetch(normalized);
  }
}
