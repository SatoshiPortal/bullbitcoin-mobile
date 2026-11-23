import 'package:flutter/widgets.dart';

import '../generated/l10n/startup_localizations.dart';

extension StartupLocalizationsContext on BuildContext {
  StartupLocalizations get loc => StartupLocalizations.of(this);
}
