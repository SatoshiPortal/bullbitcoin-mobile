import 'package:bb_mobile/core/swaps/domain/usecases/rescue_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restore_swaps_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/swap_rescue_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/swap_restore_cubit.dart';
import 'package:bb_mobile/features/settings/settings_locator.dart';
import 'package:bb_mobile/core/swaps/swaps_locator.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

/// Swap restore and rescue are registered again.
///
/// `543102768 chore(swap): remove the orphaned Boltz orchestration` removed
/// their registrations because `RestoreSwapsUsecase` had never been registered
/// at all, so the cubit could not be built and the screen was unreachable. The
/// repository half survived that cleanup untouched, and the agreed settings
/// hierarchy places Restore swaps in Wallet and Bitcoin, so both use cases and
/// both cubits are registered here rather than the screen being simulated.
void main() {
  test('the swap restore and rescue cubits can be built', () {
    final locator = GetIt.asNewInstance();

    SettingsLocator.setup(locator);

    expect(locator.isRegistered<SwapRestoreCubit>(), isTrue);
    expect(locator.isRegistered<SwapRescueCubit>(), isTrue);
  });

  test('their use cases are registered, which is what was missing before', () {
    final locator = GetIt.asNewInstance();

    SwapsLocator.registerUsecases(locator);

    expect(locator.isRegistered<RestoreSwapsUsecase>(), isTrue);
    expect(locator.isRegistered<RescueSwapUsecase>(), isTrue);
  });

  test('both swap recovery routes are published', () {
    final routeNames = SettingsRouter.route().routes.whereType<GoRoute>().map(
      (route) => route.name,
    );

    expect(routeNames, contains('swapRestore'));
    expect(routeNames, contains('swapRescue'));
  });
}
