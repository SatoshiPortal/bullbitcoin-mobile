import 'package:primitives/primitives.dart';

/// The app preferences used to authorize developer networks and select Tor.
typedef ElectrumPreferences = ({
  bool? isSuperuser,
  bool? isDevModeEnabled,
  bool useTorProxy,
  int torProxyPort,
});

/// Reads the current preferences before any Electrum route can be opened.
typedef ReadElectrumPreferences =
    Future<Result<ElectrumPreferences, Failure>> Function();
