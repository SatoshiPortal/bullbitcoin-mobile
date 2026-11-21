import 'package:signers/src/signer_device.dart';
import 'package:signers/src/ledger/domain/entities/ledger_device_entity.dart';
import 'package:signers/src/ledger/domain/ledger_failure.dart';
import 'package:signers/src/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class ScanLedgerDevicesUsecase {
  final LedgerDeviceRepository _repository;

  ScanLedgerDevicesUsecase({required this._repository});

  @useResult
  Future<Result<List<LedgerDeviceEntity>, LedgerFailure>> execute({
    SignerDevice? deviceType,
  }) {
    return _repository.scanDevices(deviceType: deviceType);
  }
}
