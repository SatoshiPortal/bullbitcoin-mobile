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
