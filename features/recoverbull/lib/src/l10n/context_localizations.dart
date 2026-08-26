import 'package:flutter/widgets.dart';

import '../../l10n/recoverbull_localizations.dart';

extension RecoverBullLocalizationsContext on BuildContext {
  RecoverBullLocalizations get recoverBullLoc =>
      RecoverBullLocalizations.of(this);

  RecoverBullLocalizations get loc => recoverBullLoc;
}
