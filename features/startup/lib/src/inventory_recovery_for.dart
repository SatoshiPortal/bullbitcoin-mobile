import 'package:legacy_storage/legacy_storage.dart';

import 'domain/app_startup_failure.dart';

/// The only startup failure that blocks instead of retrying: the wallet
/// storage's own data is unreadable. Another owner, a locked keystore,
/// contention and an unsupported schema are not.
InventoryRecoveryRequired? inventoryRecoveryFor(LegacyImportFailure failure) =>
    switch (failure) {
      LegacyOwnerFailure(
        ownerId: 'secrets',
        ownerDataLost: true,
        :final cause,
      ) =>
        InventoryRecoveryRequired(switch (cause) {
          LegacyOwnerFailureCause.keyLost => InventoryRecoveryCause.keyLost,
          LegacyOwnerFailureCause.missingAfterAdmission =>
            InventoryRecoveryCause.missingAfterAdmission,
          _ => InventoryRecoveryCause.unreadable,
        }),
      _ => null,
    };
