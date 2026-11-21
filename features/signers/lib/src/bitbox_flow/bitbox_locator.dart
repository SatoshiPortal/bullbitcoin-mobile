import 'package:signers/src/bitbox_flow/domain/disconnect_bitbox_device_usecase.dart';
import 'package:signers/src/bitbox_flow/domain/dispose_bitbox_connections_usecase.dart';
import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:signers/src/bitbox/domain/usecases/connect_bitbox_device_usecase.dart';
import 'package:signers/src/bitbox/domain/usecases/scan_bitbox_devices_usecase.dart';
import 'package:signers/src/bitbox_flow/presentation/cubit/bitbox_operation_cubit.dart';
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
