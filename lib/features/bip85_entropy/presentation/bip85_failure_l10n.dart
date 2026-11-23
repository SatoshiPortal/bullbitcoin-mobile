import 'package:bb_mobile/features/bip85_entropy/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:flutter/widgets.dart';

extension Bip85FailureL10n on Bip85Failure {
  String toTranslated(BuildContext context) => switch (this) {
    Bip85NoDefaultWalletFailure() => context.loc.bip85NoDefaultWalletError,
    Bip85DerivationFailure() => context.loc.oopsSomethingWentWrong,
    Bip85StorageFailure() => context.loc.oopsSomethingWentWrong,
    Bip85UnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
