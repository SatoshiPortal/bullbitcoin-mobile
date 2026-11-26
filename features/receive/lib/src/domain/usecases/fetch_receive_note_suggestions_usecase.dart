import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:labels/labels.dart';

import '../receive_failure.dart';

import 'package:meta/meta.dart';

/// Receive-owned wrapper around the labels feature's public contract.
class FetchReceiveNoteSuggestionsUsecase {
  final Labels _labelsFacade;

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
        (await _labelsFacade.suggestions(type: LabelType.address))
            .fold((suggestions) => suggestions, (_) => const <String>{}),
      );
    } on Exception catch (e, st) {
      // Logged HERE, at the boundary that owns the raw reason. The failure's
      // logMessage stays secondary (equality, debug): if a caller chooses not
      // to log, the diagnostic must still exist.
      log.warning(
        'Failed to load receive note suggestions',
        error: e.runtimeType,
        trace: st,
      );
      return Err(ReceiveUnexpectedFailure(e.toString()));
    }
  }
}
