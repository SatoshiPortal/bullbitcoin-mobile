import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/ledger_failure.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class ScanLedgerDevicesUsecase {
  final LedgerDeviceRepository _repository;

  ScanLedgerDevicesUsecase({required this._repository});

  @useResult
  Future<Result<List<LedgerDeviceEntity>, LedgerFailure>> execute({
    SignerDeviceEntity? deviceType,
  }) {
    return _repository.scanDevices(deviceType: deviceType);
  }
}
