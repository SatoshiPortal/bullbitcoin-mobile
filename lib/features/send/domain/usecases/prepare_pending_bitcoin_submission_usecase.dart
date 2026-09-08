import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/domain/pending_bitcoin_transaction.dart';
import 'package:bb_mobile/features/send/domain/repositories/pending_bitcoin_transaction_repository.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:meta/meta.dart';

class PreparePendingBitcoinSubmissionUsecase {
  final PendingBitcoinTransactionRepository _repository;

  const PreparePendingBitcoinSubmissionUsecase(this._repository);

  /// Retains the exact payment before publication can start. Hashlock secrets
  /// stay ephemeral, so their editable draft must be removed first instead.
  @useResult
  Future<Result<PendingBitcoinTransaction?, SendFailure>> execute(
    PendingBitcoinTransaction transaction, {
    required int expectedRevision,
    required bool containsPreimages,
  }) async {
    if (!transaction.isSubmission) {
      throw ArgumentError('Expected a payment submission');
    }
    if (containsPreimages) {
      return _repository
          .delete(transaction.id, expectedRevision: expectedRevision)
          .then((result) => result.map((_) => null));
    }
    return _repository.save(transaction, expectedRevision: expectedRevision);
  }
}
