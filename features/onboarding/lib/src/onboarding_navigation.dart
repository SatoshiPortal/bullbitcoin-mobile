import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

enum OnboardingRoute {
  onboarding('/onboarding'),
  splash('splash'),
  recoverOptions('recover-options'),
  recoverFromPhysical('recover-from-physical');

  final String path;

  const OnboardingRoute(this.path);
}

abstract final class OnboardingNavigation {
  static final physicalRecoveryPath =
      '${OnboardingRoute.onboarding.path}/${OnboardingRoute.recoverFromPhysical.path}';

  static void go(GoRouter router) =>
      router.goNamed(OnboardingRoute.onboarding.name);

  static Future<void> openPhysicalRecovery(BuildContext context) =>
      context.pushNamed<void>(OnboardingRoute.recoverFromPhysical.name);
}
