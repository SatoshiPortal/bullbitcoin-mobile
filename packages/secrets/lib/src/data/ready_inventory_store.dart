import 'dart:io';

import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart'
    show
        LegacyImportDeferred,
        LegacyImportFailure,
        LegacyImportVerificationFailed,
        LegacyOwnerFailure,
        LegacyOwnerFailureCause;
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import '../domain/domain.dart';
import 'encrypted_database.dart' show databaseFileProblemOf;
import 'inventory_import.dart';
import 'inventory_store.dart';
import 'view_format.dart';

/// Opens an existing inventory and checks its import receipt before any
/// capability can use the connection. Shared by every reader of the file.
///
/// The supported view layout is checked here, so every opener (foreground
/// inventory, background descriptors and both Ark capabilities) refuses what
/// this build cannot read before any of them uses the connection.
Future<Result<InventoryStore, DatabaseOpenFailure>> openReadyInventoryStore(
  File file,
  RuntimeAdmission admission,
) async {
  final result = await InventoryStore.open(file, admission, existing: true);
  switch (result) {
    case Err():
      return result;
    case Ok(:final value):
      switch (await readInventoryReadiness(value.database, admitted: true)) {
        case Ok(value: OwnerReadiness.imported || OwnerReadiness.initialized):
          try {
            switch (await checkSupportedViewFormat(value.database)) {
              case Err(:final failure):
                await value.close();
                return Err(failure);
              case Ok():
                return result;
            }
          } on SqliteException catch (error) {
            // Damage to a page of the layout tables is the file's content.
            await value.close();
            return Err(DatabaseFileUnavailable(databaseFileProblemOf(error)));
          } on Exception {
            await value.close();
            return const Err(
              DatabaseFileUnavailable(DatabaseFileProblem.inaccessible),
            );
          }
        case Ok():
          await value.close();
          return const Err(DatabaseNotReady());
        case Err(:final failure):
          await value.close();
          return Err(inventoryReadinessFailure(failure));
      }
  }
}

/// What a failed readiness check on an admitted inventory means to the open.
/// Each cause survives, so a caller can tell damaged data from a locked
/// keystore, contention, a newer format or a plain access error. Only
/// [DatabaseFileProblem.unreadable] and a missing key say the data is lost.
DatabaseOpenFailure inventoryReadinessFailure(LegacyImportFailure failure) =>
    switch (failure) {
      LegacyImportDeferred() => const DatabaseKeyUnavailable(
        DatabaseKeyProblem.locked,
      ),
      LegacyOwnerFailure(:final cause) => switch (cause) {
        LegacyOwnerFailureCause.keystoreLocked => const DatabaseKeyUnavailable(
          DatabaseKeyProblem.locked,
        ),
        LegacyOwnerFailureCause.keyLost => const DatabaseKeyUnavailable(
          DatabaseKeyProblem.missing,
        ),
        LegacyOwnerFailureCause.contention => const DatabaseFileUnavailable(
          DatabaseFileProblem.contended,
        ),
        LegacyOwnerFailureCause.unsupportedSchema =>
          const DatabaseFileUnavailable(DatabaseFileProblem.schemaMismatch),
        LegacyOwnerFailureCause.unreadable => const DatabaseFileUnavailable(
          DatabaseFileProblem.unreadable,
        ),
        LegacyOwnerFailureCause.missingAfterAdmission =>
          const DatabaseFileUnavailable(DatabaseFileProblem.missing),
      },
      // A receipt this build cannot read says nothing about the file.
      LegacyImportVerificationFailed() => const DatabaseFileUnavailable(
        DatabaseFileProblem.inconsistent,
      ),
      _ => const DatabaseFileUnavailable(DatabaseFileProblem.inaccessible),
    };
