import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/locator.dart';

class BuyLocator {
  static void setup() {
    registerBlocs();
  }

  static void registerBlocs() {
    locator.registerFactory<BuyBloc>(
      () => BuyBloc(
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
      ),
    );
  }
}
