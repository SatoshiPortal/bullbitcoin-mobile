import 'dart:io';

import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart' show SqliteException;

import '../domain/recoverbull_failure.dart';
import 'database/recoverbull_database.dart';

RecoverBullFailure recoverBullStorageFailure(Object error) {
  final cause = error is DriftRemoteException ? error.remoteCause : error;
  if (cause is SqliteException) {
    // SQLite extended result codes retain the primary code in the low byte.
    switch (cause.resultCode & 0xff) {
      case 13:
        return const RecoverBullStorageFullFailure();
      case 11:
      case 26:
        return const RecoverBullStorageDamagedFailure();
    }
  }
  if (cause is FileSystemException && cause.osError?.errorCode == 28) {
    return const RecoverBullStorageFullFailure();
  }
  if (cause is RecoverBullDatabaseIntegrityException) {
    return const RecoverBullStorageDamagedFailure();
  }
  return const RecoverBullJournalFailure();
}
