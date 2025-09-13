import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';

class ScanLedgerDevicesUsecase {
  final LedgerDeviceRepository _repository;

  ScanLedgerDevicesUsecase({required LedgerDeviceRepository repository})
      : _repository = repository;

  Future<List<LedgerDeviceEntity>> execute() async {
    return await _repository.scanDevices();
  }
}
