import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

extension Bip85FailureL10n on Bip85Failure {
  String toTranslated(BuildContext context) => switch (this) {
    Bip85NoDefaultWalletFailure() => context.loc.bip85NoDefaultWalletError,
    Bip85DerivationFailure() => context.loc.oopsSomethingWentWrong,
    Bip85StorageFailure() => context.loc.oopsSomethingWentWrong,
    Bip85UnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
