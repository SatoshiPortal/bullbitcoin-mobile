import 'package:flutter/widgets.dart';

import '../generated/l10n/settings_localizations.dart';

extension SettingsCopy on BuildContext {
  SettingsLocalizations get loc => SettingsLocalizations.of(this);
}
