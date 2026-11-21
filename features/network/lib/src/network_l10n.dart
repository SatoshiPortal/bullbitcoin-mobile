import 'package:flutter/widgets.dart';

import '../generated/l10n/network_localizations.dart';

extension NetworkL10n on BuildContext {
  NetworkLocalizations get loc => NetworkLocalizations.of(this);
}
