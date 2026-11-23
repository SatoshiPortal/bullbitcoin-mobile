import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('publishes the legacy swap recovery routes', () {
    final routeNames = SettingsRouter.childRoutes(
      accessRoutes: const [],
      addressRoutes: const [],
      exchangeSettingsRoutes: const [],
      appSettingsRoutes: const [],
      backupRoutes: const [],
      priceRoutes: const [],
      walletRoutes: [
        GoRoute(
          name: 'walletDetailsMarker',
          path: 'wallet-details-marker',
          builder: (_, _) => throw StateError('Unexpected wallet details'),
        ),
      ],
    ).whereType<GoRoute>().map((route) => route.name);

    expect(routeNames, contains('swapRestore'));
    expect(routeNames, contains('swapRescue'));
    // The wallet detail routes their owner publishes stay reachable.
    expect(routeNames, contains('walletDetailsMarker'));
  });
}
