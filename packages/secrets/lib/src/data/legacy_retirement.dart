import 'dart:io';

import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import 'inventory_import.dart';
import 'inventory_store.dart';
import 'legacy_fingerprint_verification.dart';
import 'secrets_database.dart';
import 'view_format.dart';

/// Retirement of the three legacy access entries of the keychain.
///
/// The proof is the Access receipt (`*-access-v2`) written by the import, and
/// for a legacy origin the fingerprint the frozen schema did not copy. Any
/// other receipt, including a reconstruction receipt, is refused: a recovery
/// does not certify that the original data is preserved.
final class SecretsRetirement implements LegacyRetirementParticipant {
  final File file;

  SecretsRetirement({required this.file});

  @override
  String get ownerId => 'secrets';

  @override
  Future<Result<void, LegacyImportFailure>> verifyRetirable(
    ExclusiveAdmission admission, {
    required OwnerOrigin origin,
    required LegacySource source,
  }) async {
    final opened = await InventoryStore.open(file, admission, existing: true);
    switch (opened) {
      case Err():
        return const Err(LegacyImportUnavailable());
      case Ok(:final value):
        try {
          final reconciled = await _hasAccessReceipt(value.database, origin);
          if (reconciled case Err(:final failure)) return Err(failure);
        } finally {
          await value.close();
        }
    }
    // Obligations of the legacy rows that the frozen schema does not copy.
    // `xpub_fingerprint` is the only one this owner holds; the other
    // uncopied columns belong to the owners whose receipts the gate checks.
    if (origin == OwnerOrigin.legacy) {
      return verifyLegacyXpubFingerprints(source);
    }
    return const Ok(null);
  }

  Future<Result<void, LegacyImportFailure>> _hasAccessReceipt(
    SecretsDatabase database,
    OwnerOrigin origin,
  ) async {
    try {
      final state = await database
          .select(database.accessState)
          .getSingleOrNull();
      final expected = origin == OwnerOrigin.legacy
          ? importedWithAccessReceipt
          : freshWithAccessReceipt;
      if (state?.importReceipt != expected) {
        return const Err(LegacyImportVerificationFailed());
      }
      // A receipt over a layout this build cannot read authorizes nothing.
      return await checkSupportedViewFormat(database) is Err
          ? const Err(LegacyImportVerificationFailed())
          : const Ok(null);
    } on SqliteException {
      return const Err(LegacyImportUnavailable());
    }
  }
}
