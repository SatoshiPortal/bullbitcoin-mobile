import 'package:bb_mobile/features/bitbox/domain/disconnect_bitbox_device_usecase.dart';
import 'package:bb_mobile/features/bitbox/domain/dispose_bitbox_connections_usecase.dart';
import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:bb_mobile/core/bitbox/domain/usecases/connect_bitbox_device_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/scan_bitbox_devices_usecase.dart';
import 'package:bb_mobile/features/bitbox/presentation/cubit/bitbox_operation_cubit.dart';
import 'package:get_it/get_it.dart';

class BitBoxLocator {
  static void setup(GetIt locator) {
    registerCubits(locator);
  }

  static void registerCubits(GetIt locator) {
    locator.registerFactoryParam<BitBoxOperationCubit, NetworkEnv, void>(
      (network, _) => BitBoxOperationCubit(
        disconnect: locator<DisconnectBitBoxDeviceUsecase>(),
        dispose: locator<DisposeBitBoxConnectionsUsecase>(),
        network: network,
        scanBitBoxDevicesUsecase: locator<ScanBitBoxDevicesUsecase>(),
        connectBitBoxDeviceUsecase: locator<ConnectBitBoxDeviceUsecase>(),
      ),
    );
  }
}
