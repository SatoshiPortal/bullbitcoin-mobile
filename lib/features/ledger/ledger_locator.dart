import 'package:bb_mobile/core/ledger/domain/usecases/connect_ledger_device_usecase.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/scan_ledger_devices_usecase.dart';
import 'package:bb_mobile/features/ledger/presentation/cubit/ledger_operation_cubit.dart';
import 'package:get_it/get_it.dart';

class LedgerLocator {
  static void setup(GetIt locator) {
    registerCubits(locator);
  }

  static void registerCubits(GetIt locator) {
    locator.registerFactory<LedgerOperationCubit>(
      () => LedgerOperationCubit(
        scanLedgerDevicesUsecase: locator<ScanLedgerDevicesUsecase>(),
        connectLedgerDeviceUsecase: locator<ConnectLedgerDeviceUsecase>(),
      ),
    );
  }
}
