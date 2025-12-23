import 'package:bb_mobile/core/status/domain/usecases/check_all_service_status_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/status_check/presentation/cubit.dart';
import 'package:get_it/get_it.dart';

class StatusCheckLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<ServiceStatusCubit>(
      () => ServiceStatusCubit(
        checkAllServiceStatusUsecase: locator<CheckAllServiceStatusUsecase>(),
        getWalletsUsecase: locator<GetWalletsUsecase>(),
      ),
    );
  }
}
