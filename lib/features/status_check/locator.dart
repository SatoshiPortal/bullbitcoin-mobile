import 'package:bb_mobile/core_deprecated/status/domain/usecases/check_all_service_status_usecase.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/status_check/presentation/cubit.dart';
import 'package:bb_mobile/locator.dart';

class StatusCheckLocator {
  static void setup() {
    locator.registerFactory<ServiceStatusCubit>(
      () => ServiceStatusCubit(
        checkAllServiceStatusUsecase: locator<CheckAllServiceStatusUsecase>(),
        getWalletsUsecase: locator<GetWalletsUsecase>(),
      ),
    );
  }
}
