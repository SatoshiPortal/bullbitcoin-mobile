import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('publishes the legacy swap recovery routes', () {
    final routeNames = SettingsRouter.route.routes.whereType<GoRoute>().map(
      (route) => route.name,
    );

    expect(routeNames, contains('swapRestore'));
    expect(routeNames, contains('swapRescue'));
  });
}
