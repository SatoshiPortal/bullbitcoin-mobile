import 'package:bb_mobile/features/tor_settings/public/tor_settings_facade.dart';
import 'package:bb_mobile/features/tor_settings/ui/screens/tor_settings_screen.dart';
import 'package:go_router/go_router.dart';

enum TorSettingsRoute {
  torSettings('tor-settings');

  final String path;
  const TorSettingsRoute(this.path);
}

class TorSettingsRouter {
  static final route = GoRoute(
    name: TorSettingsRoute.torSettings.name,
    path: TorSettingsRoute.torSettings.path,
    builder: (context, state) =>
        const TorSettingsScope(child: TorSettingsScreen()),
  );
}
