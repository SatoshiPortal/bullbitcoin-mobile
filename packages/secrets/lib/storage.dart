/// Foreground wallet inventory and the narrow descriptor capability for background sync.
library;

export 'src/domain/access_attempt.dart';
export 'src/domain/inventory_backup_verification.dart';
export 'src/domain/recorded_derivation.dart';
export 'src/domain/registered_wallet.dart';
export 'src/public/secrets_inventory.dart'
    show BackgroundWalletDescriptors, SecretsInventory;
