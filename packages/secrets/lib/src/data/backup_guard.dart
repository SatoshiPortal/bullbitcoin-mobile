import 'dart:async';

import 'package:drift/drift.dart' show Variable;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:synchronized/synchronized.dart';

import '../domain/domain.dart';
import 'boundary.dart' show InventorySessionEnded;
import '../domain/inventory_backup_verification.dart';
import 'secrets_database.dart';

// Native SQLite calls block this isolate. Queue local contenders before they
// can block the transaction holding the SQLite write lock.
final _inventoryWrites = Lock();

Future<T> inventoryWriteTransaction<T>(
  SecretsDatabase database,
  Future<T> Function() action,
) => guardedTransaction(database, action);

/// Zone key under which an inventory operation publishes "my session is still
/// the live one". Read by [guardedTransaction] just before the commit.
const inventorySessionCheck = #secretsInventorySessionCheck;

/// A transaction that refuses to commit after its session ended. The check is
/// made inside the transaction, after the last write and before the commit:
/// checking after an `await` outside would not undo anything.
Future<T> guardedTransaction<T>(
  SecretsDatabase database,
  Future<T> Function() action,
) => _inventoryWrites.synchronized(
  () => database.transaction(() async {
    final result = await action();
    final live = Zone.current[inventorySessionCheck];
    if (live is bool Function() && !live()) throw const InventorySessionEnded();
    return result;
  }),
);

/// Completes once every write already queued or running has settled.
Future<void> inventoryWritesSettled() => _inventoryWrites.synchronized(() {});

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
    Iterable<Fingerprint> secrets, {
    ({String walletId, bool regtest})? replacingWallet,
  }) async {
    final pending = secrets.toSet();
    if (pending.isEmpty) return const Ok([]);
    final verifier = _verifier;
    if (verifier == null) return const Err(BackupVerifierUnboundFailure());
    final missing = <Fingerprint>[];
    SecretFailure? unreadable;
    for (final secret in pending) {
      switch (await verifier.verify(secret, replacingWallet: replacingWallet)) {
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
  Future<SecretFailure?> require(
    Iterable<Fingerprint> secrets, {
    ({String walletId, bool regtest})? replacingWallet,
  }) async =>
      switch (await missing(secrets, replacingWallet: replacingWallet)) {
        Err(:final failure) => failure,
        Ok(value: final missing) when missing.isNotEmpty =>
          BackupRequiredFailure(missing),
        Ok() => null,
      };

  /// A legacy protected view may already contain unbacked secrets. Preparing
  /// another wallet must not destroy an existing proof, but it does not add a
  /// secret and must not require the legacy view to acquire new proofs.
  Future<SecretFailure?> requirePreserved(
    Iterable<Fingerprint> secrets, {
    required ({String walletId, bool regtest}) replacingWallet,
  }) async {
    final surviving = await missing(secrets, replacingWallet: replacingWallet);
    if (surviving case Err(:final failure)) return failure;
    final after = (surviving as Ok<List<Fingerprint>, SecretFailure>).value;
    if (after.isEmpty) return null;
    final current = await missing(after);
    if (current case Err(:final failure)) return failure;
    final alreadyMissing = (current as Ok<List<Fingerprint>, SecretFailure>)
        .value
        .toSet();
    final lost = after.where((secret) => !alreadyMissing.contains(secret));
    return lost.isEmpty ? null : BackupRequiredFailure(lost);
  }
}
