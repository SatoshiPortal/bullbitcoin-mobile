import 'package:bip32_keys/bip32_keys.dart';
import 'package:convert/convert.dart' show hex;
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

/// Check that the legacy fingerprint omitted by the frozen schema can be
/// reconstructed exactly. Also check every legacy row in the retirement
/// coordinator's other projections before allowing destruction of [source].
@useResult
Result<void, LegacyImportFailure> verifyLegacyXpubFingerprints(
  LegacySource source,
) {
  if (source.schemaVersion != 16) {
    return const Err(LegacySourceSchemaMismatch());
  }
  try {
    final legacy = sqlite3.open(source.file.path, mode: OpenMode.readOnly);
    try {
      legacy.execute('BEGIN');
      if (legacy.userVersion != source.schemaVersion) {
        return const Err(LegacySourceSchemaMismatch());
      }
      final rows = legacy.select(
        'SELECT xpub, xpub_fingerprint FROM wallet_metadatas',
      );
      for (final row in rows) {
        final xpub = row['xpub'];
        if (xpub is! String ||
            !_matchesFingerprint(xpub, row['xpub_fingerprint'])) {
          return const Err(LegacyImportVerificationFailed());
        }
      }
      return const Ok(null);
    } finally {
      legacy.close();
    }
  } on SqliteException {
    return const Err(LegacyImportUnavailable());
  }
}

bool _matchesFingerprint(String xpub, Object? expected) {
  try {
    // Accepted legacy rows include several SLIP-132 public version prefixes.
    final key = Bip32Keys.fromBase58(xpub, bypassVersion: true);
    final private = key.private;
    if (private != null) {
      private.fillRange(0, private.length, 0);
      return false;
    }
    return hex.encode(key.fingerprint) == expected;
  } on FormatException {
    return false;
  } on ArgumentError {
    // Bip32Keys reports malformed persisted keys as ArgumentError.
    return false;
  }
}
