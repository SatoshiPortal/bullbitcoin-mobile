import 'package:bb_mobile/core/exchange/domain/usecases/get_api_key_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_api_key_usecase.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_home_cubit.dart';
import 'package:bb_mobile/locator.dart';

class ExchangeLocator {
  static void setup() {
    registerBlocs();
  }

  static void registerBlocs() {
    locator.registerLazySingleton<ExchangeHomeCubit>(
      () => ExchangeHomeCubit(
        saveApiKeyUsecase: locator<SaveApiKeyUsecase>(),
        getApiKeyUsecase: locator<GetApiKeyUsecase>(),
        getUserSummaryUsecase: locator<GetUserSummaryUsecase>(),
      ),
    );
  }
}
