import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each [RecipientsFailure]. The `sealed`
/// switch makes a missing message a compile error.
///
/// Never returns `logMessage`. The reasons behind these failures are
/// JSON-RPC error objects and parse errors over recipient payloads, so they
/// carry both server internals and the user's own banking details.
extension RecipientsFailureL10n on RecipientsFailure {
  String toTranslated(BuildContext context) => switch (this) {
    RecipientsUnsupportedNetworkFailure() =>
      context.loc.networkFeatureUnavailable,
    RecipientsNotAuthenticatedFailure() => context.loc.exchangeAuthErrorMessage,
    RecipientsLoadFailure() => context.loc.recipientsErrorLoadFailed,
    RecipientsSaveFailure() => context.loc.recipientsErrorSaveFailed,
    final RecipientsInvalidFieldsFailure refused =>
      context.loc.recipientsErrorFieldsRefused(
        refused.refusedFieldNames(except: const {}).join(', '),
      ),
    RecipientsSaveOutcomeUnknownFailure() =>
      context.loc.recipientsErrorSaveOutcomeUnknown,
    RecipientsSinpeLookupFailure() =>
      context.loc.recipientsErrorSinpeLookupFailed,
    RecipientsCadBillerSearchFailure() =>
      context.loc.recipientsErrorBillerSearchFailed,
    RecipientsNetworkFailure() => context.loc.recipientsErrorNetwork,
    RecipientsVirtualIbanNotAvailableFailure() =>
      context.loc.recipientsErrorVirtualIbanNotAvailable,
    RecipientsEuResidencyRequiredFailure() =>
      context.loc.recipientsErrorEuResidencyRequired,
    // Deliberately does NOT say the save failed: it succeeded, and a message
    // that implies otherwise invites a retry and a duplicate recipient.
    RecipientsSavedButNotSelectedFailure() =>
      context.loc.recipientsErrorSavedButNotSelected,
    // The cause belongs to the feature that supplied the hook, so this one
    // gets the shared generic message rather than inventing a description of
    // someone else's failure.
    // InvalidSecurityDetails only comes back from the Interac update that
    //  withdraw drives, and withdraw validates those fields in its own form
    //  first, so reaching here is unexpected.
    RecipientsSelectionFailure() ||
    RecipientsInvalidSecurityDetailsFailure() ||
    RecipientsUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}

/// The refused fields a form names under each field, and the rest.
extension RecipientsInvalidFieldsFailureL10n on RecipientsInvalidFieldsFailure {
  /// The API names of the refused fields, leaving out the fields in [except]
  /// (the ones the form marks under the field itself).
  List<String> refusedFieldNames({required Set<RecipientField> except}) => [
    for (final field in fields.keys)
      if (!except.contains(field)) field.wireName,
    ...otherFields,
  ];

  /// The message under the Continue button of a form that marks the
  /// [shownFields] itself.
  String summary(BuildContext context, Set<RecipientField> shownFields) {
    final rest = refusedFieldNames(except: shownFields);
    return rest.isEmpty
        ? context.loc.recipientsErrorCheckFields
        : context.loc.recipientsErrorFieldsRefused(rest.join(', '));
  }
}

/// The message under a form [field] the exchange refused, or null.
extension RecipientFieldProblemL10n on RecipientFieldProblem {
  String toTranslated(BuildContext context) => switch (this) {
    RecipientFieldProblem.missing =>
      context.loc.recipientsValidationFieldRequired,
    RecipientFieldProblem.invalid => context.loc.recipientsErrorFieldRefused,
  };
}
