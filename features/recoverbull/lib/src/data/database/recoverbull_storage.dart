import 'package:drift/native.dart' show NativeDatabase;
import 'package:legacy_storage/coordination.dart';
import 'package:primitives/primitives.dart';

import '../../domain/recoverbull_failure.dart';
import '../recoverbull_storage_failure.dart';
import 'recoverbull_cutover.dart';
import 'recoverbull_database.dart';

/// Owns a single connection and preserves unavailable or future databases.
final class RecoverBullStorage {
  final String path;
  final RecoverBullCutover? cutover;
  final RuntimeAdmission? admission;
  Future<RecoverBullDatabase>? _opening;
  RecoverBullDatabase? _database;
  LifecycleHandle? _handle;
  bool _disposed = false;
  bool _temporary = false;
  RecoverBullFailure? _unavailableFailure;

  RecoverBullStorage(this.path, {this.cutover, this.admission});

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
    final selected = cutover;
    final lease = admission;
    if (selected != null || lease != null) {
      if (selected == null || lease == null) {
        throw const LifecycleException('recoverbull_admission');
      }
      final opened = await selected.open(lease);
      if (opened case Ok(:final value)) {
        if (_disposed) {
          await value.handle.close();
          throw const LifecycleException('recoverbull_disposed');
        }
        _handle = value.handle;
        return _accept(value.database);
      }
      throw const LifecycleException('recoverbull_open');
    }
    final database = RecoverBullDatabase.open(path);
    try {
      await database.forceOpen();
    } on Exception catch (error) {
      _unavailableFailure = recoverBullStorageFailure(error);
      await database.close();
      // Replacing corrupt metadata would silently discard own-operation
      // markers and alarms. Preserve the file and offer manual-key recovery.
      rethrow;
    }
    return _accept(database);
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
      await database.close();
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
