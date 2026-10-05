import 'package:bb_mobile/core/failures/failure.dart';

sealed class ExchangeSettingsFailure extends Failure {
  const ExchangeSettingsFailure([super.logMessage]);
}

/// The trading statistics could not be retrieved.
final class ExchangeSettingsStatisticsUnavailableFailure
    extends ExchangeSettingsFailure {
  const ExchangeSettingsStatisticsUnavailableFailure([super.logMessage]);
}

/// The account details backing the upload screen could not be retrieved.
final class ExchangeSettingsAccountUnavailableFailure
    extends ExchangeSettingsFailure {
  const ExchangeSettingsAccountUnavailableFailure([super.logMessage]);
}

/// A document has already been submitted, so no further upload is accepted.
final class ExchangeSettingsDocumentAlreadySubmittedFailure
    extends ExchangeSettingsFailure {
  const ExchangeSettingsDocumentAlreadySubmittedFailure([super.logMessage]);
}

/// The chosen file is empty.
final class ExchangeSettingsDocumentEmptyFailure
    extends ExchangeSettingsFailure {
  const ExchangeSettingsDocumentEmptyFailure([super.logMessage]);
}

/// The chosen file exceeds the size the exchange accepts.
final class ExchangeSettingsDocumentTooLargeFailure
    extends ExchangeSettingsFailure {
  const ExchangeSettingsDocumentTooLargeFailure([super.logMessage]);
}

/// The chosen file is not one of the accepted document formats.
final class ExchangeSettingsDocumentTypeNotAllowedFailure
    extends ExchangeSettingsFailure {
  const ExchangeSettingsDocumentTypeNotAllowedFailure([super.logMessage]);
}

/// The chosen file could not be read off the device.
final class ExchangeSettingsDocumentUnreadableFailure
    extends ExchangeSettingsFailure {
  const ExchangeSettingsDocumentUnreadableFailure([super.logMessage]);
}

/// The document was read but the exchange rejected or dropped the upload.
///
/// The API's own sentence arrives in `logMessage` and stays there.
final class ExchangeSettingsDocumentUploadFailure
    extends ExchangeSettingsFailure {
  const ExchangeSettingsDocumentUploadFailure([super.logMessage]);
}

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI —
/// the presentation extension returns the shared generic string.
final class ExchangeSettingsUnexpectedFailure extends ExchangeSettingsFailure {
  const ExchangeSettingsUnexpectedFailure([super.logMessage]);
}
