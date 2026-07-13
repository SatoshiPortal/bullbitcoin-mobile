import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/errors/ledger_failure.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class ConnectLedgerDeviceUsecase {
  final LedgerDeviceRepository _repository;

  ConnectLedgerDeviceUsecase({required this._repository});

  @useResult
  Future<Result<void, LedgerFailure>> execute(LedgerDeviceEntity device) {
    return _repository.connectDevice(device);
  }
}
