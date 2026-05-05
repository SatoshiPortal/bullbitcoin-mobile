import 'package:bb_mobile/features/wizard/ui/screens/wizard_route_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum WizardRoute {
  wizard('/wizard');

  final String path;
  const WizardRoute(this.path);
}

class WizardRouter {
  static GoRoute get route => GoRoute(
    name: WizardRoute.wizard.name,
    path: WizardRoute.wizard.path,
    pageBuilder: (context, state) =>
        const MaterialPage(fullscreenDialog: true, child: WizardRouteScreen()),
  );
}
