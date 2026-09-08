import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:meta/meta.dart';

/// Receive-owned wrapper around the labels feature's public contract.
class FetchReceiveNoteSuggestionsUsecase {
  final LabelsFacade _labelsFacade;

  const FetchReceiveNoteSuggestionsUsecase(this._labelsFacade);

  /// Distinct user-defined address labels, for the suggestion chips in the
  /// note bottom sheet.
  ///
  /// Scoped to [LabelType.address] because the chosen string becomes a
  /// counterparty-visible BIP21 `message=` — private transaction labels must
  /// never be surfaced here.
  @useResult
  Future<Result<Set<String>, ReceiveFailure>> execute() async {
    try {
      return Ok(
        await _labelsFacade.fetchDistinctLabels(type: LabelType.address),
      );
    } on Object catch (e, st) {
      // Logged HERE, at the boundary that owns the raw reason. The failure's
      // logMessage stays secondary (equality, debug): if a caller chooses not
      // to log, the diagnostic must still exist.
      log.warning(
        'Failed to load receive note suggestions',
        error: e,
        trace: st,
      );
      return Err(ReceiveUnexpectedFailure(e.toString()));
    }
  }
}
