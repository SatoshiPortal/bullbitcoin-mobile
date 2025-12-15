import 'package:bb_mobile/core_deprecated/bitbox/domain/usecases/connect_bitbox_device_usecase.dart';
import 'package:bb_mobile/core_deprecated/bitbox/domain/usecases/scan_bitbox_devices_usecase.dart';
import 'package:bb_mobile/features/bitbox/presentation/cubit/bitbox_operation_cubit.dart';
import 'package:bb_mobile/locator.dart';

class BitBoxLocator {
  static void setup() {
    registerCubits();
  }

  static void registerCubits() {
    locator.registerFactory<BitBoxOperationCubit>(
      () => BitBoxOperationCubit(
        scanBitBoxDevicesUsecase: locator<ScanBitBoxDevicesUsecase>(),
        connectBitBoxDeviceUsecase: locator<ConnectBitBoxDeviceUsecase>(),
      ),
    );
  }
}
