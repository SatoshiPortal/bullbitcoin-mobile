import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/ledger_failure.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class DisconnectLedgerDeviceUsecase {
  final LedgerDeviceRepository _repository;

  DisconnectLedgerDeviceUsecase({required this._repository});

  @useResult
  Future<Result<void, LedgerFailure>> execute(LedgerDeviceEntity device) =>
      _repository.disconnectConnection(device);
}
