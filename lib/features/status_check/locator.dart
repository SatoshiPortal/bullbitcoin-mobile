import 'package:bb_mobile/features/status_check/domain/check_all_service_status_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/status_check/domain/check_service_status_usecase.dart';
import 'package:bb_mobile/features/status_check/presentation/cubit.dart';
import 'package:get_it/get_it.dart';

class StatusCheckLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<CheckServiceStatusUsecase>(
      () => CheckServiceStatusUsecase(
        checkAllServiceStatusUsecase: locator<CheckAllServiceStatusUsecase>(),
        getWalletsUsecase: locator<GetWalletsUsecase>(),
      ),
    );
    locator.registerFactory<ServiceStatusCubit>(
      () => ServiceStatusCubit(
        checkServiceStatusUsecase: locator<CheckServiceStatusUsecase>(),
      ),
    );
  }
}
