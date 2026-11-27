import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';

import 'package:access/src/locator.dart';
import 'package:access/src/pin_code_locator.dart';
import 'package:secrets/storage.dart';
import 'package:access/src/domain/access_inventory.dart';
import 'package:access/src/domain/usecases/attempt_unlock_with_pin_code_usecase.dart';
import 'package:access/src/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:access/src/domain/usecases/get_latest_unlock_attempt_usecase.dart';
import 'package:access/src/presentation/bloc/app_unlock_bloc.dart';
import 'package:get_it/get_it.dart';

void _setupAccess(GetIt locator, {required SecretsInventory inventory}) {
  accessLocator = locator;
  locator.registerSingleton(AccessInventory(inventory));
  PinCodeLocator.setup(locator);

  // Use cases
  locator.registerFactory<GetLatestUnlockAttemptUsecase>(
    () => GetLatestUnlockAttemptUsecase(inventory: locator<AccessInventory>()),
  );
  locator.registerFactory<CheckPinCodeExistsUsecase>(
    () => CheckPinCodeExistsUsecase(inventory: locator<AccessInventory>()),
  );
  locator.registerFactory<AttemptUnlockWithPinCodeUsecase>(
    () =>
        AttemptUnlockWithPinCodeUsecase(inventory: locator<AccessInventory>()),
  );

  // Blocs
  locator.registerFactory<AppUnlockBloc>(
    () => AppUnlockBloc(
      checkPinCodeExistsUsecase: locator<CheckPinCodeExistsUsecase>(),
      getLatestUnlockAttemptUsecase: locator<GetLatestUnlockAttemptUsecase>(),
      attemptUnlockWithPinCodeUsecase:
          locator<AttemptUnlockWithPinCodeUsecase>(),
    ),
  );
}

/// Routes contributed at their existing root and settings locations.
typedef AccessRouteContributions = ({
  List<RouteBase> root,
  List<RouteBase> settings,
});

/// Mount once before startup; dependencies are resolved only when used.
final class AccessFeature {
  final AccessRouteContributions routes;

  const AccessFeature._(this.routes);

  static AccessFeature mount({
    required GetIt services,
    required SecretsInventory inventory,
    required void Function(BuildContext) onUnlocked,
    required Future<void> Function(BuildContext) onBackUp,
  }) {
    _setupAccess(services, inventory: inventory);
    return AccessFeature._((
      root: List.unmodifiable([AccessRoutes.unlock(onUnlocked: onUnlocked)]),
      settings: List.unmodifiable([
        AccessRoutes.pinSettings(onBackUp: onBackUp),
      ]),
    ));
  }
}
