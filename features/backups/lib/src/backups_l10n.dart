import 'package:flutter/widgets.dart';

import '../generated/l10n/backups_localizations.dart';

extension BackupsL10n on BuildContext {
  BackupsLocalizations get loc => BackupsLocalizations.of(this);
}
