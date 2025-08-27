import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/dca/presentation/dca_bloc.dart';
import 'package:bb_mobile/locator.dart';

class DcaLocator {
  static void setup() {
    registerBlocs();
  }

  static void registerBlocs() {
    locator.registerFactory<DcaBloc>(
      () => DcaBloc(
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
      ),
    );
  }
}
