import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';

/// Tears down every ledger connection and the underlying transport.
///
/// Called when the operation flow is disposed. Best-effort, like
/// [DisconnectLedgerDeviceUsecase]: nothing here is user-actionable.
class DisposeLedgerConnectionsUsecase {
  final LedgerDeviceRepository _repository;

  DisposeLedgerConnectionsUsecase({required this._repository});

  Future<void> execute() => _repository.dispose();
}
