import 'dart:io';

import 'package:legacy_storage/coordination.dart';
import 'package:primitives/primitives.dart';

import '../domain/domain.dart';
import 'inventory_import.dart';
import 'inventory_store.dart';

/// Opens an existing inventory and checks its import receipt before any
/// capability can use the connection. Shared by every reader of the file.
Future<Result<InventoryStore, DatabaseOpenFailure>> openReadyInventoryStore(
  File file,
  RuntimeAdmission admission,
) async {
  final result = await InventoryStore.open(file, admission, existing: true);
  switch (result) {
    case Err():
      return result;
    case Ok(:final value):
      switch (await readInventoryReadiness(value.database)) {
        case Ok(value: OwnerReadiness.imported || OwnerReadiness.initialized):
          return result;
        case Ok():
          await value.close();
          return const Err(DatabaseNotReady());
        case Err():
          await value.close();
          return const Err(
            DatabaseFileUnavailable(DatabaseFileProblem.unreadable),
          );
      }
  }
}
