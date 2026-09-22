import 'package:bb_mobile/core/failures/failure.dart';

sealed class RecipientsFailure extends Failure {
  const RecipientsFailure([super.logMessage]);
}

final class RecipientActivationFailure extends RecipientsFailure {
  const RecipientActivationFailure([super.logMessage]);
}

final class RecipientRefreshFailure extends RecipientsFailure {
  const RecipientRefreshFailure([super.logMessage]);
}

final class VirtualIbanFailure extends RecipientsFailure {
  const VirtualIbanFailure([super.logMessage]);
}
