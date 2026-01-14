import 'package:bb_mobile/core/exchange/domain/usecases/create_virtual_iban_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_virtual_iban_details_usecase.dart';
import 'package:bb_mobile/features/virtual_iban/presentation/virtual_iban_bloc.dart';
import 'package:get_it/get_it.dart';

class VirtualIbanLocator {
  static void setup(GetIt locator) {
    registerBlocs(locator);
  }

  static void registerBlocs(GetIt locator) {
    // Register as lazy singleton - single instance shared across app
    // Auto-starts on first access to load VIBAN details
    // Following BB-Exchange's EuVibanCubit pattern
    locator.registerLazySingleton<VirtualIbanBloc>(
      () => VirtualIbanBloc(
        getVirtualIbanDetailsUsecase: locator<GetVirtualIbanDetailsUsecase>(),
        createVirtualIbanUsecase: locator<CreateVirtualIbanUsecase>(),
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
      )..add(const VirtualIbanEvent.started()), // Auto-load on creation
    );
  }
}
