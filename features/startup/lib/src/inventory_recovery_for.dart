import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart' show Failure;
import 'package:secrets/secrets.dart'
    show
        DatabaseFileProblem,
        DatabaseFileUnavailable,
        DatabaseKeyProblem,
        DatabaseKeyUnavailable;

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

/// The same diagnosis for a failure of the wallet inventory's own opening,
/// once the storage was admitted. Null when the failure says nothing about
/// the storage's data, a locked keystore, contention or its format.
LegacyOwnerFailure? inventoryOpenFailureOf(Failure failure) {
  final cause = switch (failure) {
    DatabaseFileUnavailable(reason: DatabaseFileProblem.unreadable) =>
      LegacyOwnerFailureCause.unreadable,
    DatabaseFileUnavailable(reason: DatabaseFileProblem.missing) =>
      LegacyOwnerFailureCause.missingAfterAdmission,
    DatabaseFileUnavailable(reason: DatabaseFileProblem.contended) =>
      LegacyOwnerFailureCause.contention,
    DatabaseFileUnavailable(reason: DatabaseFileProblem.schemaMismatch) =>
      LegacyOwnerFailureCause.unsupportedSchema,
    DatabaseKeyUnavailable(reason: DatabaseKeyProblem.locked) =>
      LegacyOwnerFailureCause.keystoreLocked,
    DatabaseKeyUnavailable(
      reason: DatabaseKeyProblem.missing || DatabaseKeyProblem.corrupt,
    ) =>
      LegacyOwnerFailureCause.keyLost,
    _ => null,
  };
  return cause == null ? null : LegacyOwnerFailure('secrets', cause);
}
