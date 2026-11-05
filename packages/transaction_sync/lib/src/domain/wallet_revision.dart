import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'transaction_sync_failure.dart';
import 'wallet_key.dart';

/// Revisions are comparable only within one key and lifecycle generation.
final class WalletRevision {
  final WalletKey key;
  final int generation;
  final int revision;

  WalletRevision({
    required this.key,
    required this.generation,
    required this.revision,
  }) {
    if (generation < 0 || revision < 0) {
      throw ArgumentError('Generation and revision must be non-negative');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is WalletRevision &&
      other.key == key &&
      other.generation == generation &&
      other.revision == revision;

  @override
  int get hashCode => Object.hash(key, generation, revision);
}

enum WalletLifecycle { active, pendingWrite, deleted }

final class WalletRevisionState {
  final WalletRevision stamp;
  final WalletLifecycle lifecycle;

  const WalletRevisionState({required this.stamp, required this.lifecycle});
}

/// D implements persistence and reconciliation. Subscribe before reading;
/// re-read on resume/open since the stream covers only the current isolate.
abstract interface class WalletRevisionReader {
  @useResult
  Future<Result<WalletRevisionState, TransactionSyncFailure>> read(
    WalletKey key,
  );
  Stream<WalletRevisionState> watch(WalletKey key);
}

/// D owns this admission capability. Hold it through Liquid hydration and
/// release in finally. Busy serves the previous stale snapshot; BDK readers
/// do not use this barrier. Admission never permits native-store writes.
abstract interface class LiquidReadLease {
  WalletRevision get revision;
  Future<void> release();
}

abstract interface class LiquidReadAdmission {
  @useResult
  Future<Result<LiquidReadLease, TransactionSyncFailure>> acquire(
    WalletKey key,
  );
}

/// A committed writer outcome includes the exact durable version to publish.
sealed class WriterOutcome {
  final WalletRevision revision;
  const WriterOutcome(this.revision);
}

final class WriterCommitted extends WriterOutcome {
  const WriterCommitted(super.revision);
}

final class WriterUnchanged extends WriterOutcome {
  const WriterUnchanged(super.revision);
}

final class ReceiveAddressIssued extends WriterOutcome {
  final String address;
  final int index;

  ReceiveAddressIssued(
    super.revision, {
    required this.address,
    required this.index,
  }) {
    if (address.isEmpty || index < 0) {
      throw ArgumentError(
        'A receive address and non-negative index are required',
      );
    }
  }
}
