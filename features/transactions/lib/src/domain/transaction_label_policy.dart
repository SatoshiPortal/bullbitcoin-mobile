/// How many notes a transaction may carry.
///
/// One rule, read by the screen (to disable "Add note") and enforced by
/// `SaveTransactionNoteUsecase`, so the limit cannot drift between them.
abstract final class TransactionLabelPolicy {
  static const maxLabels = 10;

  static bool canAdd(int existingLabels) => existingLabels < maxLabels;
}
