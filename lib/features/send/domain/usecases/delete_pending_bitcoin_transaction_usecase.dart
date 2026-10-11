import 'package:primitives/primitives.dart' show Result;
import 'package:bb_mobile/features/send/domain/repositories/pending_bitcoin_transaction_repository.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:meta/meta.dart';

class DeletePendingBitcoinTransactionUsecase {
  final PendingBitcoinTransactionRepository _repository;

  const DeletePendingBitcoinTransactionUsecase(this._repository);

  @useResult
  Future<Result<void, SendFailure>> execute(
    String id, {
    required int expectedRevision,
  }) => _repository.delete(id, expectedRevision: expectedRevision);
}
