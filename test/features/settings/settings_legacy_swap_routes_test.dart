import 'package:bb_mobile/features/settings/presentation/bloc/swap_restore_cubit.dart';
import 'package:bb_mobile/features/settings/settings_locator.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('does not register the unavailable legacy swap restore flow', () {
    final locator = GetIt.asNewInstance();

    SettingsLocator.setup(locator);

    expect(locator.isRegistered<SwapRestoreCubit>(), isFalse);
  });

  test('does not publish unavailable legacy swap recovery routes', () {
    final routeNames = SettingsRouter.route.routes.whereType<GoRoute>().map(
      (route) => route.name,
    );

    expect(routeNames, isNot(contains('swapRestore')));
    expect(routeNames, isNot(contains('swapRescue')));
  });
}
