import 'package:primitives/primitives.dart';
import 'package:sync/src/domain/coin_freezes.dart';
import 'package:sync/src/domain/ports/legacy_freeze_source_port.dart';
import 'package:sync/src/domain/sync_failure.dart';

/// The app's freeze table, as a test sets it. [failure] makes it unreadable.
final class LegacyFreezes implements LegacyFreezeSourcePort {
  List<FrozenOutpoint> rows;
  SyncFailure? failure;
  int reads = 0;

  LegacyFreezes([this.rows = const []]);

  @override
  Future<Result<List<FrozenOutpoint>, SyncFailure>> readAll() async {
    reads++;
    final failure = this.failure;
    return failure == null ? Ok(List.of(rows)) : Err(failure);
  }
}

Future<Result<void, SyncFailure>> freezesReady() async => const Ok(null);
