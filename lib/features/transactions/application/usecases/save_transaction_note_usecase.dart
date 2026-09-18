import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:meta/meta.dart';

/// Stores a note on a wallet transaction.
///
/// The labels feature is reached through its facade, and its `LabelFailure` is
/// translated into this feature's family right here: nothing above this line
/// should know another feature's failure type.
class SaveTransactionNoteUsecase {
  final LabelsFacade _labelsFacade;

  const SaveTransactionNoteUsecase(this._labelsFacade);

  @useResult
  Future<Result<Label, TransactionFailure>> execute({
    required String transactionId,
    required String label,
    required String? origin,
  }) async {
    final stored = await _labelsFacade.store(
      NewLabel.tx(transactionId: transactionId, label: label, origin: origin),
    );
    return stored.mapErr(
      (failure) => TransactionUnexpectedFailure(
        'store note failed: ${failure.runtimeType}',
      ),
    );
  }
}
