import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';

import 'package:access/src/locator.dart';
import 'package:access/src/pin_code_locator.dart';
import 'package:secrets/secrets.dart';
import 'package:access/src/data/repositories/failed_unlock_attempts_repository_impl.dart';
import 'package:access/src/data/services/exponential_timeout_calculator.dart';
import 'package:access/src/domain/services/timeout_calculator.dart';
import 'package:access/src/domain/services/unlock_cooldown.dart';
import 'package:access/src/domain/usecases/attempt_unlock_with_pin_code_usecase.dart';
import 'package:access/src/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:access/src/domain/usecases/get_latest_unlock_attempt_usecase.dart';
import 'package:access/src/presentation/bloc/app_unlock_bloc.dart';
import 'package:get_it/get_it.dart';

void _setupAccess(
  GetIt locator, {
  required Future<bool> Function() hasVerifiedBackup,
}) {
  accessLocator = locator;
  PinCodeLocator.setup(locator, hasVerifiedBackup: hasVerifiedBackup);

  // Repositories
  locator.registerLazySingleton<FailedUnlockAttemptsRepository>(
    () => FailedUnlockAttemptsRepository(locator<Secrets>().accessKeychain),
  );

  // Services
  locator.registerLazySingleton<TimeoutCalculator>(
    () => ExponentialTimeoutCalculator(),
  );
  locator.registerLazySingleton<UnlockCooldown>(() => UnlockCooldown());

  // Use cases
  locator.registerFactory<GetLatestUnlockAttemptUsecase>(
    () => GetLatestUnlockAttemptUsecase(
      failedUnlockAttemptsRepository: locator<FailedUnlockAttemptsRepository>(),
      timeoutCalculator: locator<TimeoutCalculator>(),
      unlockCooldown: locator<UnlockCooldown>(),
    ),
  );
  locator.registerFactory<CheckPinCodeExistsUsecase>(
    () => CheckPinCodeExistsUsecase(
      accessKeychain: locator<Secrets>().accessKeychain,
    ),
  );
  locator.registerFactory<AttemptUnlockWithPinCodeUsecase>(
    () => AttemptUnlockWithPinCodeUsecase(
      failedUnlockAttemptsRepository: locator<FailedUnlockAttemptsRepository>(),
      accessKeychain: locator<Secrets>().accessKeychain,
      timeoutCalculator: locator<TimeoutCalculator>(),
      unlockCooldown: locator<UnlockCooldown>(),
    ),
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
    required Future<bool> Function() hasVerifiedBackup,
    required void Function(BuildContext) onUnlocked,
    required Future<void> Function(BuildContext) onBackUp,
  }) {
    _setupAccess(services, hasVerifiedBackup: hasVerifiedBackup);
    return AccessFeature._((
      root: List.unmodifiable([AccessRoutes.unlock(onUnlocked: onUnlocked)]),
      settings: List.unmodifiable([
        AccessRoutes.pinSettings(onBackUp: onBackUp),
      ]),
    ));
  }
}
