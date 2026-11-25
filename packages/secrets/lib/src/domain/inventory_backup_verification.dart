import 'package:primitives/primitives.dart';

import 'failures.dart';

/// What the backup owner can prove about one secret.
enum BackupProof {
  /// A tested backup of this secret exists.
  verified,

  /// Every readable store was read and none proves this secret.
  missing,
}

/// Evidence supplied by the backup owner for one secret of a view.
///
/// The composition binds one verifier when it opens the inventory; a caller of
/// the inventory never supplies its own attestation. Called during an
/// inventory update: implementations read their own state and must not
/// reenter the inventory or wait on a wallet operation.
///
/// One positive proof is enough. [BackupProof.missing] means every store was
/// read without finding proof. An unreadable store with no positive proof is an
/// [Err], never a [BackupProof.missing].
abstract interface class InventoryBackupVerification {
  Future<Result<BackupProof, SecretFailure>> verify(Fingerprint secret);
}
