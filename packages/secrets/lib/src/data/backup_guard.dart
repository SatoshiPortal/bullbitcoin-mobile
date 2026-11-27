import 'dart:async';

import 'package:drift/drift.dart' show Variable;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:synchronized/synchronized.dart';

import '../domain/domain.dart';
import 'boundary.dart' show InventorySessionEnded;
import '../domain/inventory_backup_verification.dart';
import 'inventory_repository.dart';
import 'secret_repository.dart';
import 'secrets_database.dart';

// Native SQLite calls block this isolate. Queue local contenders before they
// can block the transaction holding the SQLite write lock.
final _inventoryWrites = Lock();

Future<T> inventoryWriteTransaction<T>(
  SecretsDatabase database,
  Future<T> Function() action, {
  bool Function(T)? catalogueChanged,
}) => guardedTransaction(database, action, catalogueChanged: catalogueChanged);

/// Zone key under which an inventory operation publishes "my session is still
/// the live one". Read by [guardedTransaction] just before the commit.
const inventorySessionCheck = #secretsInventorySessionCheck;
const inventoryCommitConfirmed = #secretsInventoryCommitConfirmed;
const inventoryCatalogueCommitConfirmed =
    #secretsInventoryCatalogueCommitConfirmed;

/// A transaction that refuses to commit after its session ended. The check is
/// made inside the transaction, after the last write and before the commit:
/// checking after an `await` outside would not undo anything.
Future<T> guardedTransaction<T>(
  SecretsDatabase database,
  Future<T> Function() action, {
  bool Function(T)? catalogueChanged,
}) => _inventoryWrites.synchronized(() async {
  final result = await database.transaction(() async {
    final result = await action();
    final live = Zone.current[inventorySessionCheck];
    if (live is bool Function() && !live()) throw const InventorySessionEnded();
    return result;
  });
  final committed = Zone.current[inventoryCommitConfirmed];
  if (committed is void Function()) committed();
  final catalogueCommitted = Zone.current[inventoryCatalogueCommitConfirmed];
  if (catalogueCommitted is void Function() &&
      catalogueChanged?.call(result) == true) {
    catalogueCommitted();
  }
  return result;
});

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
/// bound at composition and the inventory's own records. Only the composition
/// can supply the verifier.
final class BackupGuard {
  final InventoryBackupVerification? _verifier;
  final SecretRepository _secrets;
  final InventoryRepository _wallets;

  @internal
  BackupGuard(this._verifier, SecretsDatabase database)
    : _secrets = SecretRepository(),
      _wallets = InventoryRepository(database);

  /// The secrets of [secrets] without a tested backup.
  ///
  /// A membership still owes a proof while it holds a stored secret, even with
  /// no wallet, and while any locally signing wallet still references it, even
  /// with no stored secret: that one is a seed to recover, not a leftover. A
  /// membership with neither is what a removed wallet leaves behind and owes
  /// nothing. A keystore or inventory that cannot be read is unknown, never
  /// absent.
  ///
  /// [newSecrets] are becoming members in this same decision. Their entry may
  /// not exist yet, so presence cannot decide anything for them: they always
  /// owe a proof.
  ///
  /// A secret that is definitely missing is reported even if another secret's
  /// state is unknown; with no definite miss, an unknown state refuses as
  /// [BackupStateUnavailableFailure] — with no verifier bound too, since that
  /// binding decides nothing when nothing owes a proof. Nothing to check needs
  /// no verifier.
  Future<Result<List<Fingerprint>, SecretFailure>> missing(
    Iterable<Fingerprint> secrets, {
    ({String walletId, bool regtest})? replacingWallet,
    Set<Fingerprint> newSecrets = const {},
  }) async {
    final pending = secrets.toSet();
    if (pending.isEmpty) return const Ok([]);
    final members = await _members(pending, newSecrets);
    var unreadable = members.unreadable;
    if (members.owed.isEmpty) {
      return unreadable
          ? const Err(BackupStateUnavailableFailure())
          : const Ok([]);
    }
    final verifier = _verifier;
    if (verifier == null) return const Err(BackupVerifierUnboundFailure());
    final missing = <Fingerprint>[];
    for (final secret in pending) {
      if (!members.owed.contains(secret)) continue;
      switch (await verifier.verify(secret, replacingWallet: replacingWallet)) {
        case Ok(value: BackupProof.verified):
          break;
        case Ok(value: BackupProof.missing):
          missing.add(secret);
        case Err():
          unreadable = true;
      }
    }
    if (missing.isNotEmpty) return Ok(List.unmodifiable(missing));
    if (unreadable) return const Err(BackupStateUnavailableFailure());
    return const Ok([]);
  }

  /// Refuses with [BackupRequiredFailure] unless every secret is verified.
  Future<SecretFailure?> require(
    Iterable<Fingerprint> secrets, {
    ({String walletId, bool regtest})? replacingWallet,
    Set<Fingerprint> newSecrets = const {},
  }) async => switch (await missing(
    secrets,
    replacingWallet: replacingWallet,
    newSecrets: newSecrets,
  )) {
    Err(:final failure) => failure,
    Ok(value: final missing) when missing.isNotEmpty => BackupRequiredFailure(
      missing,
    ),
    Ok() => null,
  };

  /// Which candidates still owe a backup.
  ///
  /// The inventory answers first, in one query: a locally signing wallet names
  /// the seed it holds, so that membership owes a proof without the keystore
  /// being touched at all. That is the ordinary case and it costs one read.
  /// Only a membership no wallet names consults the keystore, entry by entry —
  /// so an unreadable entry that is not a candidate cannot decide these — and
  /// only there is a stored seed paid for, or a leftover recognised.
  Future<({Set<Fingerprint> owed, bool unreadable})> _members(
    Set<Fingerprint> candidates,
    Set<Fingerprint> newSecrets,
  ) async {
    final owed = <Fingerprint>{
      for (final secret in candidates)
        if (newSecrets.contains(secret)) secret,
    };
    final unreferenced = candidates.difference(owed);
    if (unreferenced.isEmpty) return (owed: owed, unreadable: false);
    final referenced = switch (await _wallets.custodyFingerprints()) {
      Ok(:final value) => value,
      Err() => null,
    };
    var unreadable = false;
    for (final secret in unreferenced) {
      if (referenced?.contains(secret) ?? false) {
        owed.add(secret);
        continue;
      }
      switch (await _secrets.describe(secret)) {
        // A stored seed with no wallet still has words to lose.
        case Ok():
          owed.add(secret);
        // No words and no wallet: what removing the last wallet leaves behind,
        // and owed nothing. Without the reference set that absence proves
        // nothing, so it stays unknown.
        case Err(failure: SecretNotFoundFailure()):
          if (referenced == null) unreadable = true;
        // Unknown is never absent.
        case Err():
          unreadable = true;
      }
    }
    return (owed: owed, unreadable: unreadable);
  }

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
