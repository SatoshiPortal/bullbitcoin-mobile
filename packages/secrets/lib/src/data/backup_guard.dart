import 'package:drift/drift.dart' show Variable;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:synchronized/synchronized.dart';

import '../domain/domain.dart';
import '../domain/inventory_backup_verification.dart';
import 'secrets_database.dart';

// Native SQLite calls block this isolate. Queue local contenders before they
// can block the transaction holding the SQLite write lock.
final _inventoryWrites = Lock();

Future<T> inventoryWriteTransaction<T>(
  SecretsDatabase database,
  Future<T> Function() action,
) => _inventoryWrites.synchronized(() => database.transaction(action));

/// Takes SQLite's write lock before any state is read, so a guard decision and
/// the write it permits see the same committed state. Every mutation that
/// depends on a guard (a credential change, a new member) starts with it.
Future<void> serializeInventoryWrites(SecretsDatabase database) =>
    database.customStatement(
      'UPDATE access_state SET singleton = singleton WHERE singleton = 1',
    );

/// The secrets a view holds: its `secret:` members, parents of BIP85 children
/// included. A watch-only member is not a secret and needs no seed proof.
Future<List<Fingerprint>> viewSecrets(
  SecretsDatabase database,
  String view,
) async {
  final rows = await database
      .customSelect(
        "SELECT member FROM view_members WHERE view_id = ? AND member LIKE 'secret:%' ORDER BY member",
        variables: [Variable(view)],
        readsFrom: {database.viewMembers},
      )
      .get();
  return List.unmodifiable([
    for (final row in rows)
      Fingerprint.tryParse(row.read<String>('member').substring(7)) ??
          (throw const FormatException('invalid view member')),
  ]);
}

/// The inventory's one reading of "is this secret backed up", over the verifier
/// bound at composition. Only the composition can supply the verifier.
final class BackupGuard {
  final InventoryBackupVerification? _verifier;

  @internal
  const BackupGuard(this._verifier);

  /// The secrets of [secrets] without a tested backup.
  ///
  /// A secret that is definitely missing is reported even if another secret's
  /// state is unknown; with no definite miss, an unknown state refuses as
  /// [BackupStateUnavailableFailure]. Nothing to check needs no verifier.
  Future<Result<List<Fingerprint>, SecretFailure>> missing(
    Iterable<Fingerprint> secrets,
  ) async {
    final pending = secrets.toSet();
    if (pending.isEmpty) return const Ok([]);
    final verifier = _verifier;
    if (verifier == null) return const Err(BackupVerifierUnboundFailure());
    final missing = <Fingerprint>[];
    SecretFailure? unreadable;
    for (final secret in pending) {
      switch (await verifier.verify(secret)) {
        case Ok(value: BackupProof.verified):
          break;
        case Ok(value: BackupProof.missing):
          missing.add(secret);
        case Err(:final failure):
          unreadable ??= failure is BackupStateUnavailableFailure
              ? failure
              : const BackupStateUnavailableFailure();
      }
    }
    if (missing.isNotEmpty) return Ok(List.unmodifiable(missing));
    if (unreadable != null) return Err(unreadable);
    return const Ok([]);
  }

  /// Refuses with [BackupRequiredFailure] unless every secret is verified.
  Future<SecretFailure?> require(Iterable<Fingerprint> secrets) async =>
      switch (await missing(secrets)) {
        Err(:final failure) => failure,
        Ok(value: final missing) when missing.isNotEmpty =>
          BackupRequiredFailure(missing),
        Ok() => null,
      };
}
