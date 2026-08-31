import 'package:bb_mobile/core/errors/send_errors.dart';

const selectedCoinsUnavailableCode = 'selected_coins_unavailable';
const selectedCoinsInsufficientCode = 'selected_coins_insufficient';
const transactionRebuildFailedCode = 'transaction_rebuild_failed';

String? transferConfirmErrorMessage({
  required BuildTransactionException? buildTransactionException,
  required String? swapFailureMessage,
  required String buildFailureMessage,
  required String selectedCoinsUnavailableMessage,
  required String selectedCoinsInsufficientMessage,
  required String transactionChangedMessage,
}) {
  if (swapFailureMessage != null) return swapFailureMessage;
  final code = buildTransactionException?.message;
  if (code == selectedCoinsUnavailableCode) {
    return selectedCoinsUnavailableMessage;
  }
  if (code == selectedCoinsInsufficientCode) {
    return selectedCoinsInsufficientMessage;
  }
  if (code == transactionRebuildFailedCode) return transactionChangedMessage;
  if (buildTransactionException != null) return buildFailureMessage;
  return null;
}
