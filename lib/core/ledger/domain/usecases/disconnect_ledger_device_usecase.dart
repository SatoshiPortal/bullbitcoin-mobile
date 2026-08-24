import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';

/// Releases the active connection to [device].
///
/// Best-effort teardown: by the time this runs the caller has already moved on,
/// so there is nothing the user could act on and no failure to surface.
class DisconnectLedgerDeviceUsecase {
  final LedgerDeviceRepository _repository;

  DisconnectLedgerDeviceUsecase({required this._repository});

  Future<void> execute(LedgerDeviceEntity device) =>
      _repository.disconnectConnection(device);
}
