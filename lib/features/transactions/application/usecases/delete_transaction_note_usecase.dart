import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:meta/meta.dart';

/// Deletes a note from a wallet transaction, translating the labels feature's
/// failure into this feature's family.
class DeleteTransactionNoteUsecase {
  final LabelsFacade _labelsFacade;

  const DeleteTransactionNoteUsecase(this._labelsFacade);

  @useResult
  Future<Result<Null, TransactionFailure>> execute(int noteId) async {
    final trashed = await _labelsFacade.trash(noteId);
    return trashed.mapErr(
      (failure) => TransactionUnexpectedFailure(
        'trash note failed: ${failure.runtimeType}',
      ),
    );
  }
}
