import 'package:bb_mobile/core/bitbox/domain/usecases/connect_bitbox_device_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/scan_bitbox_devices_usecase.dart';
import 'package:bb_mobile/features/bitbox/presentation/cubit/bitbox_operation_cubit.dart';
import 'package:get_it/get_it.dart';

class BitBoxLocator {
  static void setup(GetIt locator) {
    registerCubits(locator);
  }

  static void registerCubits(GetIt locator) {
    locator.registerFactory<BitBoxOperationCubit>(
      () => BitBoxOperationCubit(
        scanBitBoxDevicesUsecase: locator<ScanBitBoxDevicesUsecase>(),
        connectBitBoxDeviceUsecase: locator<ConnectBitBoxDeviceUsecase>(),
      ),
    );
  }
}
