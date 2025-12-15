import 'package:bb_mobile/core_deprecated/exchange/domain/usecases/delete_exchange_api_key_usecase.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/usecases/save_exchange_api_key_usecase.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/usecases/save_user_preferences_usecase.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:get_it/get_it.dart';

class ExchangeLocator {
  static void setup(GetIt locator) {
    registerBlocs(locator);
  }

  static void registerBlocs(GetIt locator) {
    locator.registerLazySingleton<ExchangeCubit>(
      () => ExchangeCubit(
        saveExchangeApiKeyUsecase: locator.get<SaveExchangeApiKeyUsecase>(),
        getExchangeUserSummaryUsecase:
            locator.get<GetExchangeUserSummaryUsecase>(),
        saveUserPreferencesUsecase: locator.get<SaveUserPreferencesUsecase>(),
        deleteExchangeApiKeyUsecase: locator.get<DeleteExchangeApiKeyUsecase>(),
      ),
    );
  }
}
