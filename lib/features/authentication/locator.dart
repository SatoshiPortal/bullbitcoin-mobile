import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/authentication/adapters/pin_repository.dart';
import 'package:bb_mobile/features/authentication/authentication_facade.dart';
import 'package:bb_mobile/features/authentication/domain/usecases/disable_authentication_usecase.dart';
import 'package:bb_mobile/features/authentication/domain/usecases/enable_authentication.dart';
import 'package:bb_mobile/features/authentication/domain/usecases/get_last_authentication_attempt_usecase.dart';
import 'package:bb_mobile/features/authentication/domain/usecases/is_authentication_required_usecase.dart';
import 'package:bb_mobile/features/authentication/domain/usecases/verify_authentication_usecase.dart';
import 'package:bb_mobile/features/authentication/presentation/settings/pin_code_setting_bloc.dart';

import 'package:get_it/get_it.dart';

import 'presentation/unlock/app_unlock_bloc.dart';

class AuthenticationLocator {
  static void setup(GetIt locator) {
    // Todo: check what can be moved to core (since the pin code repository is needed both in settings as in app unlock)

    // Repositories
    locator.registerLazySingleton<PinRepository>(
      () => PinRepository(
        locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
      ),
    );

    // Local use-case shims that adapt the repository to the use-case shape
    // expected by the rest of the codebase (PinCodeSettingBloc).
    locator.registerFactory<EnableAuthenticationUsecase>(
      () =>
          EnableAuthenticationUsecase(authentication: locator<PinRepository>()),
    );

    locator.registerFactory<DisableAuthenticationUsecase>(
      () => DisableAuthenticationUsecase(
        authentication: locator<PinRepository>(),
      ),
    );

    locator.registerFactory<IsAuthenticationRequiredUsecase>(
      () => IsAuthenticationRequiredUsecase(
        authentication: locator<PinRepository>(),
      ),
    );

    locator.registerFactory<VerifyAuthenticationUsecase>(
      () =>
          VerifyAuthenticationUsecase(authentication: locator<PinRepository>()),
    );

    locator.registerFactory<GetLastAuthenticationAttemptUsecase>(
      () => GetLastAuthenticationAttemptUsecase(
        authenticationPort: locator<PinRepository>(),
      ),
    );

    // Blocs
    locator.registerFactory<PinCodeSettingBloc>(
      () => PinCodeSettingBloc(
        enableAuthenticationUsecase: locator<EnableAuthenticationUsecase>(),
        disableAuthenticationUsecase: locator<DisableAuthenticationUsecase>(),
        isAuthenticationRequiredUsecase:
            locator<IsAuthenticationRequiredUsecase>(),
      ),
    );

    locator.registerFactory<AppUnlockBloc>(
      () => AppUnlockBloc(
        isAuthenticationRequiredUsecase:
            locator<IsAuthenticationRequiredUsecase>(),
        verifyAuthenticationUsecase: locator<VerifyAuthenticationUsecase>(),
        getLastAuthenticationAttemptUsecase:
            locator<GetLastAuthenticationAttemptUsecase>(),
      ),
    );

    locator.registerLazySingleton<AuthenticationFacade>(
      () => AuthenticationFacade(
        enableAuthenticationUsecase: locator<EnableAuthenticationUsecase>(),
        disableAuthenticationUsecase: locator<DisableAuthenticationUsecase>(),
        isAuthenticationRequiredUsecase:
            locator<IsAuthenticationRequiredUsecase>(),
        verifyAuthenticationUsecase: locator<VerifyAuthenticationUsecase>(),
      ),
    );
  }
}
