import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/status_check/domain/status_check_failure.dart';
import 'package:flutter/widgets.dart';

extension StatusCheckFailureL10n on StatusCheckFailure {
  String toTranslated(BuildContext context) => switch (this) {
    NoDefaultWalletFailure() => context.loc.statusCheckNoDefaultWalletError,
    StatusCheckUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
