import 'package:bb_mobile/core_deprecated/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core_deprecated/ledger/domain/repositories/ledger_device_repository.dart';

class ConnectLedgerDeviceUsecase {
  final LedgerDeviceRepository _repository;

  ConnectLedgerDeviceUsecase({required LedgerDeviceRepository repository})
      : _repository = repository;

  Future<void> execute(LedgerDeviceEntity device) async {
    await _repository.connectDevice(device);
  }
}
