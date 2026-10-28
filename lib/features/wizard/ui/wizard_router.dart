import 'package:bb_mobile/features/wizard/ui/screens/permissions_intro_screen.dart';
import 'package:go_router/go_router.dart';

enum WizardRoute {
  permissionsIntro('/permissions-intro');

  final String path;

  const WizardRoute(this.path);
}

class WizardRouter {
  static final route = GoRoute(
    name: WizardRoute.permissionsIntro.name,
    path: WizardRoute.permissionsIntro.path,
    builder: (context, state) => const PermissionsIntroScreen(),
  );
}
