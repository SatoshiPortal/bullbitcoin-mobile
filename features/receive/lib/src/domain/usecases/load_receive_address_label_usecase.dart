import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:labels/labels.dart';

import '../receive_failure.dart';

import 'package:meta/meta.dart';

/// Receive-owned wrapper around the labels feature's public contract.
class LoadReceiveAddressLabelUsecase {
  final Labels _labelsFacade;

  const LoadReceiveAddressLabelUsecase(this._labelsFacade);

  /// The note previously saved against [address], or an empty string when
  /// there is none.
  ///
  /// System labels (e.g. seed-injected metadata) are skipped: they are not
  /// user-authored notes and must never pre-fill the note field.
  @useResult
  Future<Result<String, ReceiveFailure>> execute(String address) async {
    try {
      final labels = (await _labelsFacade.fetch(reference: address))
          .fold((labels) => labels, (_) => const <Label>[]);
      for (final label in labels) {
        if (!LabelSystem.isSystemLabel(label.label)) return Ok(label.label);
      }
      return const Ok('');
    } on Exception catch (e, st) {
      // Logged HERE, at the boundary that owns the raw reason. The failure's
      // logMessage stays secondary (equality, debug): if a caller chooses not
      // to log, the diagnostic must still exist.
      log.warning(
        'Failed to load the receive address label',
        error: e.runtimeType,
        trace: st,
      );
      return Err(ReceiveUnexpectedFailure(e.toString()));
    }
  }
}
