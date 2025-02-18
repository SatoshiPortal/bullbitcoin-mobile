import 'package:bb_mobile/features/settings/presentation/screens/settings_screen.dart';
import 'package:go_router/go_router.dart';

enum SettingsRoute {
  settings('/settings');

  final String path;

  const SettingsRoute(this.path);
}

class SettingsRouter {
  static final route = GoRoute(
    name: SettingsRoute.settings.name,
    path: SettingsRoute.settings.path,
    builder: (context, state) => const SettingsScreen(),
  );
}
