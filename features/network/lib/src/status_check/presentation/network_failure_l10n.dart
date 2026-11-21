import '../../network_l10n.dart';
import '../domain/network_failure.dart';

import 'package:flutter/widgets.dart';

extension NetworkFailureL10n on NetworkFailure {
  String toTranslated(BuildContext context) => switch (this) {
    NoDefaultWalletFailure() => context.loc.statusCheckNoDefaultWalletError,
    NetworkUnexpectedFailure() ||
    StatusCheckInterruptedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
