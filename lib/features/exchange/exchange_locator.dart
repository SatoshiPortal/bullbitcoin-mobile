import 'package:bb_mobile/core/exchange/domain/usecases/accelerate_buy_order_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/delete_exchange_api_key_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_exchange_api_key_usecase.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_home_cubit.dart';
import 'package:bb_mobile/locator.dart';

class ExchangeLocator {
  static void setup() {
    registerBlocs();
  }

  static void registerBlocs() {
    locator.registerLazySingleton<ExchangeHomeCubit>(
      () => ExchangeHomeCubit(
        saveExchangeApiKeyUsecase: locator.get<SaveExchangeApiKeyUsecase>(),
        deleteExchangeApiKeyUsecase: locator.get<DeleteExchangeApiKeyUsecase>(),
        getExchangeUserSummaryUsecase:
            locator.get<GetExchangeUserSummaryUsecase>(),
        accelerateBuyOrderUsecase: locator.get<AccelerateBuyOrderUsecase>(),
      ),
    );
  }
}
