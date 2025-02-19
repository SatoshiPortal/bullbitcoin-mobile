import 'package:bb_mobile/features/settings/presentation/screens/language_settings_screen.dart';
import 'package:go_router/go_router.dart';

enum SettingsSubroute {
  language('language');

  final String path;

  const SettingsSubroute(this.path);
}

class SettingsRouter {
  static final routes = [
    GoRoute(
      name: SettingsSubroute.language.name,
      path: SettingsSubroute.language.path,
      builder: (context, state) => const LanguageSettingsScreen(),
    ),
  ];
}
