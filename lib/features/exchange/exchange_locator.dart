import 'package:bb_mobile/core/exchange/domain/usecases/delete_exchange_api_key_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_exchange_api_key_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_user_preferences_usecase.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/locator.dart';

class ExchangeLocator {
  static void setup() {
    registerBlocs();
  }

  static void registerBlocs() {
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
