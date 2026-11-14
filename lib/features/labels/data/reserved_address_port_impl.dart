import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_system.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

final class ReservedAddressPortImpl implements ReservedAddressPort {
  final LabelsRepositoryPort _labels;

  ReservedAddressPortImpl(this._labels);

  @override
  Future<Result<bool, TransactionSyncFailure>> isReserved(
    WalletKey key,
    String address,
  ) async {
    // Existing labels are global by reference, not scoped to wallet origin.
    // Keep this behavior, including labels imported without an origin.
    try {
      final labels = await _labels.fetchByReference(address);
      return Ok(labels.any((label) => LabelSystem.isSystemLabel(label.label)));
    } on Exception {
      return const Err(TransactionSyncStorageFailure());
    }
  }
}
