import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_funding_details_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:get_it/get_it.dart';

class FundExchangeLocator {
  static void setup(GetIt locator) {
    registerBlocs(locator);
  }

  static void registerBlocs(GetIt locator) {
    locator.registerFactory<FundExchangeBloc>(
      () => FundExchangeBloc(
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
        getExchangeFundingDetailsUsecase:
            locator<GetExchangeFundingDetailsUsecase>(),
      ),
    );
  }
}
