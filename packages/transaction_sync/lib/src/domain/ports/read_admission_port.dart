import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../transaction_sync_failure.dart';
import '../wallet_key.dart';
import '../wallet_revision.dart';

/// The writer owns brief hydration admission for Bitcoin and Liquid. Hold it
/// only through existence checks, open and load; release before reads or PSBT construction. Busy serves the
/// previous stale snapshot. Admission never permits native-store writes.
abstract interface class ReadLease {
  WalletRevision get revision;
  Future<void> release();
}

abstract interface class ReadAdmissionPort {
  @useResult
  Future<Result<ReadLease, TransactionSyncFailure>> acquire(WalletKey key);
}
