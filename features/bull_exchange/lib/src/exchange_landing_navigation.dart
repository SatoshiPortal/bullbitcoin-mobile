import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Navigation to the public exchange landing route.
abstract final class BullExchangeNavigation {
  static const landingName = 'exchangeLanding';
  static const landingPath = '/exchange/landing';
  static const dashboardName = 'exchangeHome';
  static const dashboardPath = '/exchange';
  static const kycName = 'exchangeKyc';

  static void goToLanding(BuildContext context) => context.goNamed(landingName);
  static void goToDashboard(BuildContext context) =>
      context.goNamed(dashboardName);
}
