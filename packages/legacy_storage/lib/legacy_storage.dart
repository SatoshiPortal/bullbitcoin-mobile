import 'dart:io';

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

const _receipts = 'legacy_import_receipts';

/// Copies one owner's data from a frozen plaintext source. Only the foreground
/// coordinator may call this, with legacy writers stopped and the destination
/// unavailable to normal operations. A false verification result rolls back
/// the copy and its receipt.
@useResult
Future<Result<void, LegacyImportFailure>> importLegacyDatabase({
  required String id,
  required File source,
  required int sourceSchemaVersion,
  required GeneratedDatabase destination,
  required Future<bool> Function(Database source) copyAndVerify,
}) async {
  try {
    await destination.transaction(() async {
      await destination.customStatement('''
        CREATE TABLE IF NOT EXISTS $_receipts (
          id TEXT PRIMARY KEY NOT NULL
        )
      ''');
      // An uncommitted claim cannot be observed by another connection.
      final claimed = await destination.customUpdate(
        'INSERT INTO $_receipts (id) VALUES (?) ON CONFLICT (id) DO NOTHING',
        variables: [Variable(id)],
      );
      if (claimed == 0) return;

      final legacy = sqlite3.open(source.path, mode: OpenMode.readOnly);
      try {
        legacy.execute('BEGIN');
        if (legacy.userVersion != sourceSchemaVersion) {
          throw const _UnexpectedSourceSchema();
        }
        if (!await copyAndVerify(legacy)) {
          throw const _VerificationRejected();
        }
      } finally {
        legacy.close();
      }
    });
    return const Ok(null);
  } on _UnexpectedSourceSchema {
    return const Err(LegacySourceSchemaMismatch());
  } on _VerificationRejected {
    return const Err(LegacyImportVerificationFailed());
  } on SqliteException {
    // Bound SQL and filesystem paths are not safe diagnostics.
    return const Err(LegacyImportUnavailable());
  } on FileSystemException {
    return const Err(LegacyImportUnavailable());
  }
}

/// Reads the committed receipt without creating or migrating a database.
/// The caller must supply an already opened, schema-checked connection.
@useResult
Future<Result<bool, LegacyImportFailure>> hasLegacyImportReceipt(
  GeneratedDatabase database,
  String id,
) async {
  try {
    final table = await database
        .customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
          variables: [const Variable(_receipts)],
        )
        .getSingleOrNull();
    if (table == null) return const Ok(false);
    final receipt = await database
        .customSelect(
          'SELECT 1 FROM $_receipts WHERE id = ?',
          variables: [Variable(id)],
        )
        .getSingleOrNull();
    return Ok(receipt != null);
  } on SqliteException {
    return const Err(LegacyImportUnavailable());
  }
}

sealed class LegacyImportFailure extends Failure {
  const LegacyImportFailure();
}

final class LegacySourceSchemaMismatch extends LegacyImportFailure {
  const LegacySourceSchemaMismatch();
}

final class LegacyImportUnavailable extends LegacyImportFailure {
  const LegacyImportUnavailable();
}

/// Why an owner that was already admitted can no longer be opened.
///
/// Only [unreadable], [keyLost] and [missingAfterAdmission] say the owner's
/// own data is gone or damaged. A locked keystore, contention and a schema this
/// build does not support are conditions of the device or of the build, and
/// say nothing about the data.
enum LegacyOwnerFailureCause {
  keystoreLocked,
  contention,
  unsupportedSchema,
  unreadable,
  keyLost,
  missingAfterAdmission,
}

/// An admitted owner failed, and which one and why.
///
/// Carries the cause the owner's storage reported instead of folding it into
/// [LegacyImportUnavailable]. It never carries a path or an engine message.
final class LegacyOwnerFailure extends LegacyImportFailure {
  final String ownerId;
  final LegacyOwnerFailureCause cause;

  const LegacyOwnerFailure(this.ownerId, this.cause);

  /// The owner's stored data cannot be read back, as opposed to a condition
  /// that retrying or updating can clear.
  bool get ownerDataLost => switch (cause) {
    LegacyOwnerFailureCause.unreadable ||
    LegacyOwnerFailureCause.keyLost ||
    LegacyOwnerFailureCause.missingAfterAdmission => true,
    LegacyOwnerFailureCause.keystoreLocked ||
    LegacyOwnerFailureCause.contention ||
    LegacyOwnerFailureCause.unsupportedSchema => false,
  };
}

final class LegacyImportVerificationFailed extends LegacyImportFailure {
  const LegacyImportVerificationFailed();
}

final class _UnexpectedSourceSchema implements Exception {
  const _UnexpectedSourceSchema();
}

final class _VerificationRejected implements Exception {
  const _VerificationRejected();
}

/// Device unlock or a later lifecycle admission may make this operation ready.
final class LegacyImportDeferred extends LegacyImportFailure {
  const LegacyImportDeferred();
}
