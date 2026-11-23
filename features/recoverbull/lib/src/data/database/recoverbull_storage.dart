import 'package:drift/native.dart' show NativeDatabase;
import 'package:legacy_storage/coordination.dart';
import 'package:primitives/primitives.dart';

import '../../domain/recoverbull_failure.dart';
import '../recoverbull_storage_failure.dart';
import 'recoverbull_cutover.dart';
import 'recoverbull_database.dart';

/// Owns a single connection and preserves unavailable or future databases.
final class RecoverBullStorage {
  final Future<RecoverBullDatabase> Function(RecoverBullStorage) _openDurable;
  Future<RecoverBullDatabase>? _opening;
  RecoverBullDatabase? _database;
  LifecycleHandle? _handle;
  bool _disposed = false;
  bool _temporary = false;
  RecoverBullFailure? _unavailableFailure;

  RecoverBullStorage({
    required RecoverBullCutover cutover,
    required RuntimeAdmission admission,
  }) : _openDurable = ((owner) async {
         final opened = await cutover.open(admission);
         if (opened case Ok(:final value)) {
           if (owner._disposed) {
             await value.handle.close();
             throw const LifecycleException('recoverbull_disposed');
           }
           owner._handle = value.handle;
           return value.database;
         }
         throw const LifecycleException('recoverbull_open');
       });

  RecoverBullStorage.forTesting(Future<RecoverBullDatabase> Function() open)
    : _openDurable = ((_) => open());

  bool get isTemporary => _temporary;
  RecoverBullFailure? get unavailableFailure => _unavailableFailure;

  Future<RecoverBullDatabase> open() {
    if (_disposed) throw StateError('RecoverBull storage is disposed');
    final database = _database;
    if (database != null) return Future.value(database);
    return _opening ??= _open().whenComplete(() {
      if (_database == null) _opening = null;
    });
  }

  Future<RecoverBullDatabase> _open() async {
    try {
      return await _accept(await _openDurable(this));
    } on Exception catch (error) {
      _unavailableFailure = recoverBullStorageFailure(error);
      rethrow;
    }
  }

  /// Only after a failed durable open and an explicit user recovery choice.
  Future<RecoverBullDatabase> openTemporary() async {
    if (_disposed || _opening != null || _database != null) {
      throw StateError('Temporary recovery requires unopened storage');
    }
    final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    try {
      await database.forceOpen();
      await database.customStatement(
        'UPDATE recoverbull_state SET monitoring_enabled = 0',
      );
    } catch (_) {
      await database.close();
      rethrow;
    }
    _temporary = true;
    return _accept(database);
  }

  Future<RecoverBullDatabase> _accept(RecoverBullDatabase database) async {
    if (_disposed) {
      if (_handle case final handle?) {
        await handle.close();
        _handle = null;
      } else {
        await database.close();
      }
      throw StateError('RecoverBull storage is disposed');
    }
    _database = database;
    return database;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final database = _database;
    _database = null;
    if (_handle case final handle?) {
      await handle.close();
      _handle = null;
    } else if (database != null) {
      await database.close();
    }
    // An in-flight open observes _disposed and closes its own connection.
  }
}
