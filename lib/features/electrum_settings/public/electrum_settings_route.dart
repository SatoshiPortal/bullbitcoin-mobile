export '../frameworks/ui/routing/electrum_settings_router.dart'
    show ElectrumSettingsRoute;

final class ElectrumSettingsArgs {
  final String prefilledServer;

  const ElectrumSettingsArgs({required this.prefilledServer});
}
