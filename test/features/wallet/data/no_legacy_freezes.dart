import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

/// A fresh install: the app's freeze table exists and is empty.
final class NoLegacyFreezes implements LegacyFreezeSourcePort {
  const NoLegacyFreezes();

  @override
  Future<Result<List<FrozenOutpoint>, SyncFailure>> readAll() async =>
      const Ok([]);
}
