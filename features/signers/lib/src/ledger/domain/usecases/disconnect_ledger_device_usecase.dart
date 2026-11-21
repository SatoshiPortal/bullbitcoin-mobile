import 'package:signers/src/ledger/domain/entities/ledger_device_entity.dart';
import 'package:signers/src/ledger/domain/ledger_failure.dart';
import 'package:signers/src/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class DisconnectLedgerDeviceUsecase {
  final LedgerDeviceRepository _repository;

  DisconnectLedgerDeviceUsecase({required this._repository});

  @useResult
  Future<Result<void, LedgerFailure>> execute(LedgerDeviceEntity device) =>
      _repository.disconnectConnection(device);
}
