import 'package:flutter/widgets.dart';

import '../../generated/l10n/recoverbull_localizations.dart';

export '../public/recoverbull_ui_labels.dart' show RecoverBullUiLabelsContext;

extension RecoverBullLocalizationsContext on BuildContext {
  RecoverBullLocalizations get recoverBullLoc =>
      RecoverBullLocalizations.of(this);

  RecoverBullLocalizations get loc => recoverBullLoc;
}
