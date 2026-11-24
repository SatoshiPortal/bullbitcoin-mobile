import 'package:primitives/primitives.dart';

import 'failures.dart';
import 'wallet_registration.dart';

/// Evidence supplied by the backup owner for a default wallet in the view.
///
/// Called during the inventory update. Implementations read their own state
/// and must not reenter the inventory or wait on a wallet operation.
abstract interface class InventoryBackupVerification {
  Future<Result<bool, SecretFailure>> hasVerifiedBackups(
    List<WalletRegistration> defaults,
  );
}
