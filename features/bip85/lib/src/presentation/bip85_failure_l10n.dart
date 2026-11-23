import 'package:bip85/src/presentation/bip85_l10n.dart';
import 'package:bip85/src/domain/bip85_failure.dart';
import 'package:flutter/widgets.dart';

extension Bip85FailureL10n on Bip85Failure {
  String toTranslated(BuildContext context) => switch (this) {
    Bip85NoDefaultWalletFailure() => context.bip85Loc.bip85NoDefaultWalletError,
    Bip85OperationFailure() => context.bip85Loc.oopsSomethingWentWrong,
  };
}
