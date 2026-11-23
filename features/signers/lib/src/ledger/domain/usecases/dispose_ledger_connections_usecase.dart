import 'package:signers/src/ledger/domain/ledger_failure.dart';
import 'package:signers/src/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

/// Tears down every ledger connection and the underlying transport.
class DisposeLedgerConnectionsUsecase {
  final LedgerDeviceRepository _repository;

  DisposeLedgerConnectionsUsecase({required this._repository});

  @useResult
  Future<Result<void, LedgerFailure>> execute() => _repository.dispose();
}
