import '../../network_l10n.dart';
import '../domain/status_check_failure.dart';

import 'package:flutter/widgets.dart';

extension StatusCheckFailureL10n on StatusCheckFailure {
  String toTranslated(BuildContext context) => switch (this) {
    NoDefaultWalletFailure() => context.loc.statusCheckNoDefaultWalletError,
    StatusCheckUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
