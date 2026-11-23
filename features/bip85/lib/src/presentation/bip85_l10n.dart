import 'package:flutter/widgets.dart';

import '../../generated/l10n/bip85_localizations.dart';

extension Bip85L10n on BuildContext {
  Bip85Localizations get bip85Loc => Bip85Localizations.of(this);
}
