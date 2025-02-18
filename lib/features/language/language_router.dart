import 'package:bb_mobile/features/language/presentation/screens/language_settings_screen.dart';
import 'package:go_router/go_router.dart';

enum LanguageRoute {
  language('/language');

  final String path;

  const LanguageRoute(this.path);
}

class LanguageRouter {
  static final route = GoRoute(
    name: LanguageRoute.language.name,
    path: LanguageRoute.language.path,
    builder: (context, state) => const LanguageSettingsScreen(),
  );
}
