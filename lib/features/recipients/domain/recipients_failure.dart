import 'package:bb_mobile/core/failures/failure.dart';

sealed class RecipientsFailure extends Failure {
  const RecipientsFailure([super.logMessage]);
}

final class RecipientsUnexpectedFailure extends RecipientsFailure {
  const RecipientsUnexpectedFailure([super.logMessage]);
}

final class RecipientsInvalidSecurityDetailsFailure extends RecipientsFailure {
  const RecipientsInvalidSecurityDetailsFailure([super.logMessage]);
}

final class RecipientsInvalidFieldsFailure extends RecipientsFailure {
  const RecipientsInvalidFieldsFailure(this.fields, [super.logMessage]);

  final Set<String> fields;
}
