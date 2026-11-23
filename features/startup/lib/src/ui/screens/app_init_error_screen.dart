import 'package:preferences/preferences.dart' show Language;

import 'dart:ui' show PlatformDispatcher;

      locale: locale,
      localizationsDelegates: [
        StartupLocalizations.delegate,
        ...widget.extraLocalizations,
