import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/locator.dart';

class FundExchangeLocator {
  static void setup() {
    registerBlocs();
  }

  static void registerBlocs() {
    locator.registerFactory<FundExchangeBloc>(
      () => FundExchangeBloc(
        getExchangeUserSummaryUseCase: locator<GetExchangeUserSummaryUsecase>(),
      ),
    );
  }
}
