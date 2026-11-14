import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

import '../../transaction_sync.dart';

/// Integration seam for lane A. Called in the isolate holding the lock, with
/// a durable sync intent already recorded. Own/load fresh native sessions here;
/// await ALL native work before returning, including failures. Never spawn a
/// worker, detach work, or use Future.timeout inside this callback. For BDK,
/// construct and invoke the writer *inside* the engine's compute worker.
///
/// Liquid must scan at least through [issuedReceiveIndex], including after a
/// repair. Ok means a completed sync, not a skipped/budget-exhausted scan.
/// Reconciliation publishes only a conservative revision, never a successful
/// sync receipt or foreground payment-seen provenance.
abstract interface class WriterSyncOperation {
  @useResult
  Future<Result<void, TransactionSyncFailure>> execute(
    PublicWalletDescriptor descriptor, {
    required int? issuedReceiveIndex,
  });
}

/// Optional proof supplied by the engine. Unknown implementations are treated
/// as potentially mutating; set true before entering any mutating native call.
abstract interface class WriterSyncMutation {
  bool get mayHaveMutated;
}

/// Optional proof for a successful sync. False means the native persister
/// reported no changes, not merely an unchanged balance or transaction count.
/// Unknown engines and failed operations remain conservative.
abstract interface class WriterSyncChanges {
  bool get hasChanges;
}

/// Positive evidence from this pass, captured before native persistence and
/// returned only after persistence succeeds. Cached unconfirmed presence is not
/// evidence. Confirmed canonical membership reconciles native spend safety.
///
/// A tracked spend that is not seen is settled for this pass only when a
/// confirmed transaction (or a tracked spend observed in this pass) spends one
/// of its inputs. Absence and eviction prove nothing; nothing is ever forgotten.
abstract interface class WriterSyncSpendObservation {
  /// Tracked txids with their recorded inputs (`txid:vout`), empty if unknown.
  void trackSpendTransactions(Map<String, Set<String>> inputsByTxid);
  Set<String> get observedSpendTransactions;

  /// Inputs of tracked transactions seen in the wallet during this pass.
  Map<String, Set<String>> get spendTransactionInputs;
  Set<String> get settledSpendTransactions;
}
