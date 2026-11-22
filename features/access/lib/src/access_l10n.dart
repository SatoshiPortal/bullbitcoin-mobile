import 'package:flutter/widgets.dart';

import '../generated/l10n/access_localizations.dart';

extension AccessLocalizationX on BuildContext {
  AccessLocalizations get loc => AccessLocalizations.of(this);
}
