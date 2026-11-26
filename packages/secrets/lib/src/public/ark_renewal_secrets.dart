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
import 'ark_background_access.dart' show arkChildBip85Index;

/// The dedicated BIP85 child of one Ark account: its words and its public
/// identity. It is never the parent seed. It is handed to the trusted Ark
/// integration for the length of one native open and goes nowhere else: not to
/// a result, a log, a field or storage.
final class ArkChild {
  /// The child's words. Strings cannot be zeroized in Dart; the scope ends when
  /// the action that received them settles.
  final String mnemonic;
  final Fingerprint fingerprint;

  const ArkChild._(this.mnemonic, this.fingerprint);

  @override
  String toString() => 'ArkChild(<redacted>)';
}

/// What the trusted Ark integration may ask of `secrets` to refresh VTXOs in
/// the background (D105).
///
/// The parent mnemonic never leaves this library: it is read inside one
/// derivation of the account's dedicated BIP85 child (index
/// [arkChildBip85Index], 12 English words) and nothing else. Only that child
/// reaches the caller, and only through [withArkChild].
///
/// This library is not exported by `package:secrets/secrets.dart`. Its single
/// importer is `packages/ark/lib/src/data/ark_renewal_child_provider.dart`;
/// an architecture test fails on any other.
///
/// Opened under the shared runtime lease like `BackgroundWalletDescriptors`.
final class ArkRenewalSecrets {
  final InventoryStore _store;
  final SecretRepository _repository;

  ArkRenewalSecrets._(this._store) : _repository = SecretRepository();

  @useResult
  static Future<Result<ArkRenewalSecrets, DatabaseOpenFailure>> open({
    required File file,
    required RuntimeAdmission admission,
  }) async =>
      (await openReadyInventoryStore(file, admission)).map(ArkRenewalSecrets._);

  /// Whether [parent] may be refreshed now, read afresh under the inventory's
  /// write lock. It reads no seed and derives nothing. The host asks before
  /// every lot of a pass, so a policy change between two lots refuses the
  /// second. An unreadable policy is a refusal.
  ///
  /// Allowed when [parent] belongs to at least one view with background access
  /// enabled. A view protected by a PIN does not refuse the refresh: it uses
  /// only the dedicated child (D105), unlike every other sensitive operation.
  /// No membership never satisfies it.
  @useResult
  Future<bool> mayRefresh(Fingerprint parent) async {
    try {
      return await inventoryWriteTransaction(_store.database, () async {
        await serializeInventoryWrites(_store.database);
        return _permitted(_store.database, parent);
      });
    } on Object {
      return false;
    }
  }

  /// Runs [action] on the Ark child of [parent] for one native open.
  ///
  /// The policy, the seed read and the derivation happen in one admission under
  /// the inventory's write lock, which is released before [action] starts: no
  /// SQLite lock is held while it runs, network included. A refusal returns
  /// [notPermitted]; an unreadable policy, a missing seed or a failed
  /// derivation return [unavailable]. Neither reads or derives anything.
  /// An action already admitted is not interrupted by a later change.
  @useResult
  Future<Result<T, F>> withArkChild<T, F extends Failure>({
    required Fingerprint parent,
    required F notPermitted,
    required F unavailable,
    required Future<Result<T, F>> Function(ArkChild child) action,
  }) async {
    final admitted = await _admit<F>(parent, notPermitted, unavailable);
    switch (admitted) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return action(value);
    }
  }

  Future<Result<ArkChild, F>> _admit<F extends Failure>(
    Fingerprint parent,
    F notPermitted,
    F unavailable,
  ) async {
    try {
      return await inventoryWriteTransaction(_store.database, () async {
        await serializeInventoryWrites(_store.database);
        if (!await _permitted(_store.database, parent)) {
          return Err(notPermitted);
        }
        final info = await _repository.describe(parent);
        if (info is! Ok<SecretInfo, SecretFailure>) return Err(unavailable);
        // The parent mnemonic is read here and only here, inside the one
        // derivation of the child. It reaches nothing else.
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
        return Ok(ArkChild._(words.value.join(' '), child.value));
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
          'SELECT v.background_enabled AS background FROM view_members m '
          'JOIN views v ON v.id = m.view_id WHERE m.member = ?',
          variables: [Variable('secret:${parent.hex}')],
          readsFrom: {database.viewMembers, database.views},
        )
        .get();
    return rows.any((row) => row.read<bool>('background'));
  }

  Future<void> close() => _store.close();
}
