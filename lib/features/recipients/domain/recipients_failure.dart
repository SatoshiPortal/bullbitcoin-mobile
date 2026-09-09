import 'package:bb_mobile/core/failures/failure.dart';

sealed class RecipientsFailure extends Failure {
  const RecipientsFailure([super.logMessage]);
}

/// The recipient list could not be loaded.
final class RecipientsLoadFailure extends RecipientsFailure {
  const RecipientsLoadFailure([super.logMessage]);
}

/// The recipient could not be saved.
final class RecipientsSaveFailure extends RecipientsFailure {
  const RecipientsSaveFailure([super.logMessage]);
}

/// The SINPE phone number could not be looked up. Distinct from a save
/// failure: the user is mid-form and the actionable advice is to check the
/// number, not to retry the whole thing.
final class RecipientsSinpeLookupFailure extends RecipientsFailure {
  const RecipientsSinpeLookupFailure([super.logMessage]);
}

/// The CAD biller directory could not be searched.
final class RecipientsCadBillerSearchFailure extends RecipientsFailure {
  const RecipientsCadBillerSearchFailure([super.logMessage]);
}

/// The request never reached the API, or timed out. Worth its own variant
/// because it is the one case with advice the user can act on.
final class RecipientsNetworkFailure extends RecipientsFailure {
  const RecipientsNetworkFailure([super.logMessage]);
}

/// The caller-supplied selection hook failed. The cause belongs to whichever
/// feature opened the recipients screen (see `RecipientsBloc`'s
/// `onRecipientSelectedHook`), so this feature reports it generically rather
/// than pretending to know what went wrong.
final class RecipientsSelectionFailure extends RecipientsFailure {
  const RecipientsSelectionFailure([super.logMessage]);
}

/// The recipient was saved, but the hook that should have carried the user
/// onward failed.
///
/// Separate from [RecipientsSelectionFailure] because of what the user does
/// next: this one appears under the Continue button of a form that has
/// already succeeded, so a message implying the save failed invites a retry
/// — and a duplicate recipient.
final class RecipientsSavedButNotSelectedFailure extends RecipientsFailure {
  const RecipientsSavedButNotSelectedFailure([super.logMessage]);
}

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI —
/// the presentation extension returns the shared generic string.
final class RecipientsUnexpectedFailure extends RecipientsFailure {
  const RecipientsUnexpectedFailure([super.logMessage]);
}
