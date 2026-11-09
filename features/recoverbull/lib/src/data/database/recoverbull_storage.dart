import 'package:drift/native.dart' show NativeDatabase;

import '../../domain/recoverbull_failure.dart';
import '../recoverbull_storage_failure.dart';
import 'recoverbull_database.dart';

/// Owns a single connection and preserves unavailable or future databases.
final class RecoverBullStorage {
  final String path;
  Future<RecoverBullDatabase>? _opening;
  RecoverBullDatabase? _database;
  bool _disposed = false;
  bool _temporary = false;
  RecoverBullFailure? _unavailableFailure;

  RecoverBullStorage(this.path);

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
    if (database != null) await database.close();
    // An in-flight open observes _disposed and closes its own connection.
  }
}
