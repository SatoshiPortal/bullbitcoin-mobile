import 'package:primitives/primitives.dart';

import '../coin_freezes.dart';
import '../sync_failure.dart';

/// The app's published freeze table, read once by the foreground to import
/// it into sync. The app owns that database and implements this port.
abstract interface class LegacyFreezeSourcePort {
  /// Every row, origins included, from one consistent read. A database that
  /// cannot be opened or read is an [Err], never an empty list: only a table
  /// the app created and found empty may answer `[]`.
  Future<Result<List<FrozenOutpoint>, SyncFailure>> readAll();
}
