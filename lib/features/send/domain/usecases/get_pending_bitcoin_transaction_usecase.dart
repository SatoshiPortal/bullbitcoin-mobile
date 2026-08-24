import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/domain/pending_bitcoin_transaction.dart';
import 'package:bb_mobile/features/send/domain/repositories/pending_bitcoin_transaction_repository.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:meta/meta.dart';

class GetPendingBitcoinTransactionUsecase {
  final PendingBitcoinTransactionRepository _repository;

  const GetPendingBitcoinTransactionUsecase(this._repository);

  @useResult
  Future<Result<PendingBitcoinTransaction?, SendFailure>> execute(String id) =>
      _repository.get(id);
}
