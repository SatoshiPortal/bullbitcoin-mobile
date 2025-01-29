import 'package:bb_mobile/core/data/datasources/key_value_storage_data_source.dart';
import 'package:bb_mobile/core/locator/di_initializer.dart';
import 'package:bb_mobile/features/language/data/repositories/language_settings_repository_impl.dart';
import 'package:bb_mobile/features/language/domain/repositories/language_settings_repository.dart';
import 'package:bb_mobile/features/language/domain/usecases/get_language_usecase.dart';
import 'package:bb_mobile/features/language/domain/usecases/set_language_usecase.dart';
import 'package:bb_mobile/features/language/presentation/bloc/language_settings_cubit.dart';

void setupLanguageDependencies() {
  // Repositories
  locator.registerLazySingleton<LanguageSettingsRepository>(
    () => LanguageSettingsRepositoryImpl(
      storage: locator<KeyValueStorageDataSource<String>>(
        instanceName: settingsStorageInstanceName,
      ),
    ),
  );

  // Usecases
  locator.registerFactory<GetLanguageUsecase>(
    () => GetLanguageUsecase(
      languageSettingsRepository: locator<LanguageSettingsRepository>(),
    ),
  );
  locator.registerFactory<SetLanguageUseCase>(
    () => SetLanguageUseCase(
      languageSettingsRepository: locator<LanguageSettingsRepository>(),
    ),
  );

  // Bloc
  locator.registerFactory<LanguageSettingsCubit>(
    () => LanguageSettingsCubit(
      setLanguageUseCase: locator<SetLanguageUseCase>(),
      getLanguageUsecase: locator<GetLanguageUsecase>(),
    ),
  );
}
