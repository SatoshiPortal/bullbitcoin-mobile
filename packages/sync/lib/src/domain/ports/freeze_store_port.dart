import 'package:primitives/primitives.dart';

import '../coin_freezes.dart';
import '../sync_failure.dart';

/// Where user freezes are kept. The app implements it over its published
/// `frozen_utxos` table; sync is its only writer, from the foreground.
///
/// A store that cannot be read or written answers an [Err], never an empty
/// list: a coin is never taken for unfrozen because the store failed.
abstract interface class FreezeStorePort {
  /// Every row, empty and repeated origins included, from one read.
  Future<Result<List<FrozenOutpoint>, SyncFailure>> readAll();

  /// Adds [rows] in one commit; a row already stored is kept as it is.
  Future<Result<void, SyncFailure>> freeze(List<FrozenOutpoint> rows);

  /// Removes every row of each outpoint, whatever its origin, in one commit.
  Future<Result<void, SyncFailure>> unfreeze(List<Outpoint> outpoints);
}
