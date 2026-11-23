import 'package:flutter/widgets.dart';

import '../generated/l10n/send_localizations.dart';

extension SendLocalizationsContext on BuildContext {
  SendLocalizations get loc => SendLocalizations.of(this);
}
