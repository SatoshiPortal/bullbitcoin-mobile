import 'package:bb_mobile/core/errors/send_errors.dart';

String? transferConfirmErrorMessage({
  required BuildTransactionException? buildTransactionException,
  required String? swapFailureMessage,
  required String buildFailureMessage,
}) {
  if (swapFailureMessage != null) return swapFailureMessage;
  if (buildTransactionException != null) return buildFailureMessage;
  return null;
}
