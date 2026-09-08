import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:meta/meta.dart';

/// Receive-owned wrapper around the labels feature's public contract.
class LoadReceiveAddressLabelUsecase {
  final LabelsFacade _labelsFacade;

  const LoadReceiveAddressLabelUsecase(this._labelsFacade);

  /// The note previously saved against [address], or an empty string when
  /// there is none.
  ///
  /// System labels (e.g. seed-injected metadata) are skipped: they are not
  /// user-authored notes and must never pre-fill the note field.
  @useResult
  Future<Result<String, ReceiveFailure>> execute(String address) async {
    try {
      final labels = await _labelsFacade.fetchByReference(address);
      for (final label in labels) {
        if (!LabelSystem.isSystemLabel(label.label)) return Ok(label.label);
      }
      return const Ok('');
    } on Object catch (e, st) {
      // Logged HERE, at the boundary that owns the raw reason. The failure's
      // logMessage stays secondary (equality, debug): if a caller chooses not
      // to log, the diagnostic must still exist.
      log.warning(
        'Failed to load the receive address label',
        error: e,
        trace: st,
      );
      return Err(ReceiveUnexpectedFailure(e.toString()));
    }
  }
}
