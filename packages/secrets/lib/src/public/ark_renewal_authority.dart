import 'dart:io';

import 'package:bip39_mnemonic/bip39_mnemonic.dart'
    show Language, MnemonicLength;
import 'package:drift/drift.dart' show Variable;
import 'package:legacy_storage/coordination.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../crypto/crypto.dart' show Deriver;
import '../data/backup_guard.dart';
import '../data/inventory_store.dart';
import '../data/ready_inventory_store.dart';
import '../data/secret_repository.dart';
import '../data/secrets_database.dart';
import '../domain/domain.dart';

/// BIP85 index of the Ark child derived from a wallet seed.
const arkChildBip85Index = 11811;

/// The one place a headless Ark task may read a seed (D92).
///
/// It is not a [Secrets] and hands out no handle: a single operation checks
/// the policy, reads the seed, derives the Ark child, runs the caller's action
/// on it and lets it go. Only a view without a PIN may be renewed while the
/// app is locked; a seed shared with a protected view is never read here.
///
/// Opened under the shared runtime lease like [BackgroundWalletDescriptors].
/// The action decides what the child is used for: the host calls this for a
/// renewal only. Saved claims rebroadcast bytes that are already signed and
/// never reach this capability.
final class ArkRenewalAuthority {
  final InventoryStore _store;
  final SecretRepository _repository;

  ArkRenewalAuthority._(this._store) : _repository = SecretRepository();

  @useResult
  static Future<Result<ArkRenewalAuthority, DatabaseOpenFailure>> open({
    required File file,
    required RuntimeAdmission admission,
  }) async => (await openReadyInventoryStore(
    file,
    admission,
  )).map(ArkRenewalAuthority._);

  /// Runs [action] on the Ark child of [parent] for one renewal.
  ///
  /// Allowed only when, read under the inventory's write lock together with
  /// the seed (a PIN set concurrently is serialized with this admission):
  ///
  /// 1. [parent] belongs to at least one view with background access enabled;
  ///    no membership never satisfies "every view is unprotected";
  /// 2. no view that contains [parent] has a credential.
  ///
  /// A refusal returns [notPermitted]. An unreadable policy, a missing seed or
  /// a failed derivation return [unavailable]. Neither reads or derives
  /// anything. An action already admitted is not interrupted by a PIN set
  /// afterwards: at most one execution is in flight, bounded by the host's
  /// stage budget.
  @useResult
  Future<Result<T, F>> withRenewalChild<T, F extends Failure>({
    required Fingerprint parent,
    required F notPermitted,
    required F unavailable,
    required Future<Result<T, F>> Function(String mnemonic, Fingerprint child)
    action,
  }) async {
    final admitted = await _admit<F>(parent, notPermitted, unavailable);
    switch (admitted) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        // Strings cannot be zeroized in Dart. No field, cache, storage or log
        // receives them; the scope ends when the action settles.
        return action(value.mnemonic, value.child);
    }
  }

  /// Whether [parent] may be renewed now, read afresh under the inventory's
  /// write lock with the same policy as [withRenewalChild]. It reads no seed
  /// and derives nothing. The host asks before every batch of a pass, so a PIN
  /// set between two batches refuses the second one. An unreadable policy is a
  /// refusal.
  @useResult
  Future<bool> mayRenew(Fingerprint parent) async {
    try {
      return await inventoryWriteTransaction(_store.database, () async {
        await serializeInventoryWrites(_store.database);
        return _permitted(_store.database, parent);
      });
    } on Object {
      return false;
    }
  }

  Future<Result<({String mnemonic, Fingerprint child}), F>> _admit<
    F extends Failure
  >(Fingerprint parent, F notPermitted, F unavailable) async {
    try {
      return await inventoryWriteTransaction(_store.database, () async {
        await serializeInventoryWrites(_store.database);
        if (!await _permitted(_store.database, parent)) {
          return Err(notPermitted);
        }
        final info = await _repository.describe(parent);
        if (info is! Ok<SecretInfo, SecretFailure>) return Err(unavailable);
        final words = await _repository.useMnemonic(
          info.value,
          (m) => Deriver.bip85.mnemonic(
            m,
            language: Language.english,
            length: MnemonicLength.words12,
            index: arkChildBip85Index,
          ),
        );
        if (words is! Ok<List<String>, SecretFailure>) return Err(unavailable);
        final child = await _repository.previewArkFingerprint(
          words: words.value,
        );
        if (child is! Ok<Fingerprint, SecretFailure>) return Err(unavailable);
        return Ok((mnemonic: words.value.join(' '), child: child.value));
      });
    } on Object {
      return Err(unavailable);
    }
  }

  static Future<bool> _permitted(
    SecretsDatabase database,
    Fingerprint parent,
  ) async {
    final rows = await database
        .customSelect(
          'SELECT v.background_enabled AS background, '
          'v.credential_id AS credential FROM view_members m '
          'JOIN views v ON v.id = m.view_id WHERE m.member = ?',
          variables: [Variable('secret:${parent.hex}')],
          readsFrom: {database.viewMembers, database.views},
        )
        .get();
    if (rows.isEmpty) return false;
    var background = false;
    for (final row in rows) {
      if (row.readNullable<String>('credential') != null) return false;
      if (row.read<bool>('background')) background = true;
    }
    return background;
  }

  Future<void> close() => _store.close();
}
