import 'package:bb_mobile/core_deprecated/ledger/domain/usecases/connect_ledger_device_usecase.dart';
import 'package:bb_mobile/core_deprecated/ledger/domain/usecases/scan_ledger_devices_usecase.dart';
import 'package:bb_mobile/features/ledger/presentation/cubit/ledger_operation_cubit.dart';
import 'package:bb_mobile/locator.dart';

class LedgerLocator {
  static void setup() {
    registerCubits();
  }

  static void registerCubits() {
    locator.registerFactory<LedgerOperationCubit>(
      () => LedgerOperationCubit(
        scanLedgerDevicesUsecase: locator<ScanLedgerDevicesUsecase>(),
        connectLedgerDeviceUsecase: locator<ConnectLedgerDeviceUsecase>(),
      ),
    );
  }
}
