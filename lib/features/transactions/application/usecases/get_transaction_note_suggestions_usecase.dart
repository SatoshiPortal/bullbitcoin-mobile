import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bull_logger/bull_logger.dart';

/// The notes already used elsewhere, offered as suggestions when writing a new
/// one. Best-effort: a failed read means no suggestions, never an error on a
/// screen whose transaction is rendering correctly.
class GetTransactionNoteSuggestionsUsecase {
  final LabelsFacade _labelsFacade;

  const GetTransactionNoteSuggestionsUsecase(this._labelsFacade);

  Future<Set<String>> execute() async {
    try {
      return await _labelsFacade.fetchDistinctLabels();
    } catch (e, st) {
      log.warning('Failed to fetch note suggestions', error: e, trace: st);
      return const {};
    }
  }
}
