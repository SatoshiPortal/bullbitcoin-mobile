import 'package:bb_mobile/core/exchange/domain/usecases/create_virtual_iban_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_virtual_iban_details_usecase.dart';
import 'package:bb_mobile/features/virtual_iban/domain/virtual_iban_location.dart';
import 'package:bb_mobile/features/virtual_iban/presentation/virtual_iban_bloc.dart';
import 'package:get_it/get_it.dart';

class VirtualIbanLocator {
  static void setup(GetIt locator) {
    registerBlocs(locator);
  }

  static void registerBlocs(GetIt locator) {
    // Register as factory with location parameter
    // The location parameter is passed when creating the bloc instance
    locator.registerFactoryParam<VirtualIbanBloc, VirtualIbanLocation, void>(
      (location, _) => VirtualIbanBloc(
        getVirtualIbanDetailsUsecase: locator<GetVirtualIbanDetailsUsecase>(),
        createVirtualIbanUsecase: locator<CreateVirtualIbanUsecase>(),
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
        location: location,
      ),
    );
  }
}

