import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/bitbox/presentation/cubit/bitbox_operation_cubit.dart';

class BitBoxDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {}

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {}

  @override
  Future<void> registerDrivingAdapters() async {
    sl.registerFactory<BitBoxOperationCubit>(
      () => BitBoxOperationCubit(
        scanBitBoxDevicesUsecase: sl(),
        connectBitBoxDeviceUsecase: sl(),
      ),
    );
  }
}
