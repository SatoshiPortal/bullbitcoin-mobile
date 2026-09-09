import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each [RecipientsFailure]. The `sealed`
/// switch makes a missing message a compile error.
///
/// Never returns `logMessage`. The reasons behind these failures are
/// JSON-RPC error objects and parse errors over recipient payloads, so they
/// carry both server internals and the user's own banking details.
///
/// In `presentation/` per rule #11, even though the rest of this feature's
/// presenters still sit under the deprecated `interface_adapters/`. Creating
/// the folder here is the convergence direction, and it gives the eventual
/// `presenters/` -> `presentation/` move somewhere to land.
extension RecipientsFailureL10n on RecipientsFailure {
  String toTranslated(BuildContext context) => switch (this) {
    RecipientsLoadFailure() => context.loc.recipientsErrorLoadFailed,
    RecipientsSaveFailure() => context.loc.recipientsErrorSaveFailed,
    RecipientsSinpeLookupFailure() =>
      context.loc.recipientsErrorSinpeLookupFailed,
    RecipientsCadBillerSearchFailure() =>
      context.loc.recipientsErrorBillerSearchFailed,
    RecipientsNetworkFailure() => context.loc.recipientsErrorNetwork,
    // Deliberately does NOT say the save failed: it succeeded, and a message
    // that implies otherwise invites a retry and a duplicate recipient.
    RecipientsSavedButNotSelectedFailure() =>
      context.loc.recipientsErrorSavedButNotSelected,
    // The cause belongs to the feature that supplied the hook, so this one
    // gets the shared generic message rather than inventing a description of
    // someone else's failure.
    RecipientsSelectionFailure() ||
    RecipientsUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
