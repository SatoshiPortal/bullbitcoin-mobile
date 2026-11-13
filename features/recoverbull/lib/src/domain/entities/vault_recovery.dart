import 'package:primitives/primitives.dart';

import '../recoverbull_failure.dart';
import 'vault_context.dart';

/// Import has committed. A subsequent wallet failure never means it did not.
sealed class VaultRecovery {
  final Fingerprint importedSecret;

  const VaultRecovery(this.importedSecret);
}

final class VaultRecovered extends VaultRecovery {
  final VaultContext context;

  VaultRecovered(this.context) : super(context.fingerprint);
}

final class VaultRecoveryNeedsWallets extends VaultRecovery {
  final RecoverBullFailure failure;

  const VaultRecoveryNeedsWallets(super.importedSecret, this.failure);
}
