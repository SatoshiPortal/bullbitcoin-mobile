import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/bump_fee_usecase.dart';

class ReplaceByFeeDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {}

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {
    sl.registerFactory<BumpFeeUsecase>(
      () => BumpFeeUsecase(
        bitcoinWalletRepository: sl(),
      ),
    );
  }

  @override
  Future<void> registerDrivingAdapters() async {}
}
