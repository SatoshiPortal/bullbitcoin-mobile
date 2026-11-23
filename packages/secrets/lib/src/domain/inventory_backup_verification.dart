import 'package:primitives/primitives.dart';

import 'failures.dart';

/// Evidence supplied by the backup owner before introducing a credential.
///
/// Called during the inventory update. Implementations read their own state
/// and must not reenter the inventory or wait on a wallet operation.
abstract interface class InventoryBackupVerification {
  Future<Result<bool, SecretFailure>> hasVerifiedBackups(
    Set<String> secretFingerprints,
  );
}
