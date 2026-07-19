import 'package:bb_mobile/features/joinstr/data/joinstr_store.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_history_entry.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_progress.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_round.dart';

/// Forwards a round's progress, persisting a history entry when it
/// broadcasts. Shared by the initiate and join usecases so the completion
/// bookkeeping cannot drift between the two.
Stream<JoinstrProgress> recordHistoryOnDone({
  required JoinstrStore store,
  required int amountSat,
  required String relay,
  required Stream<JoinstrProgress> progress,
}) async* {
  await for (final p in progress) {
    if (p.step == JoinstrRoundStep.done && p.txId != null) {
      await store.appendHistory(
        JoinstrHistoryEntry(
          amountSat: amountSat,
          txId: p.txId!,
          relay: relay,
          completedAtUnixSec: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        ),
      );
    }
    yield p;
  }
}
