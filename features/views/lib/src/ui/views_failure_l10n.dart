import 'package:flutter/widgets.dart';

import '../../generated/l10n/views_localizations.dart';
import '../domain/views_failure.dart';

/// The message a failure shows. The unexpected case is generic on purpose.
extension ViewsFailureL10n on ViewsFailure {
  String toTranslated(BuildContext context) {
    final l10n = ViewsLocalizations.of(context);
    return switch (this) {
      ViewsUnavailableFailure() => l10n.viewsUnavailable,
      ViewsLastViewFailure() => l10n.viewLastCannotDelete,
      ViewsHoldsSecretsFailure() => l10n.viewHoldsSecretsCannotDelete,
      ViewsInUseFailure() => l10n.viewInUseCannotDelete,
      ViewsInvalidNameFailure() => l10n.viewNameInvalid,
      ViewsUnexpectedFailure() => l10n.viewsSomethingWentWrong,
    };
  }
}
