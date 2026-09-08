import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:meta/meta.dart';

/// Receive-owned wrapper around the labels feature's public contract.
class SaveReceiveAddressLabelUsecase {
  final LabelsFacade _labelsFacade;

  const SaveReceiveAddressLabelUsecase(this._labelsFacade);

  /// Persists [note] as the address label for [address], or removes the
  /// existing address labels when [note] is empty.
  ///
  /// The empty-note case is a delete rather than a store of `''`: the label
  /// store treats an empty label as a real value, so writing one would leave
  /// the address permanently annotated with a blank note.
  ///
  /// The labels feature's [LabelFailure] is mapped here, at the boundary this
  /// feature owns, so neither the bloc nor the receive UI ever holds another
  /// feature's failure type.
  @useResult
  Future<Result<void, ReceiveFailure>> execute({
    required String address,
    required String walletId,
    required String note,
  }) async {
    try {
      if (note.isEmpty) {
        final labels = await _labelsFacade.fetchByReference(address);
        for (final label in labels.where(
          (label) => label.type == LabelType.address,
        )) {
          final result = await _labelsFacade.trash(label.id);
          if (result case Err(:final failure)) {
            return Err(ReceiveNoteNotSavedFailure(failure.logMessage));
          }
        }
        return const Ok(null);
      }

      final result = await _labelsFacade.store(
        NewLabel.addr(address: address, origin: walletId, label: note),
      );
      return switch (result) {
        Ok() => const Ok(null),
        Err(:final failure) => Err(
          ReceiveNoteNotSavedFailure(failure.logMessage),
        ),
      };
    } on Object catch (e, st) {
      // Logged HERE, at the boundary that owns the raw reason. The failure's
      // logMessage stays secondary (equality, debug): if a caller chooses not
      // to log, the diagnostic must still exist.
      log.warning(
        'Failed to save the receive address label',
        error: e,
        trace: st,
      );
      return Err(ReceiveNoteNotSavedFailure(e.toString()));
    }
  }
}
