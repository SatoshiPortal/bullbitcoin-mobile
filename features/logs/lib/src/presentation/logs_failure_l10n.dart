import 'package:flutter/widgets.dart';
import 'package:bull_logs/generated/l10n/logs_localizations.dart';
import '../domain/logs_failure.dart';

extension LogsFailureL10n on LogsFailure {
  String toTranslated(BuildContext context) =>
      LogsLocalizations.of(context).oopsSomethingWentWrong;
}
