/// The app preferences used to authorize developer networks and select Tor.
typedef ElectrumPreferences = ({
  bool? isSuperuser,
  bool? isDevModeEnabled,
  bool useTorProxy,
  int torProxyPort,
});
