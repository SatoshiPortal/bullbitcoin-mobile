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
import '../data/view_format.dart' show multiViewSupported;
import '../domain/domain.dart';
import 'ark_background_access.dart' show arkChildBip85Index;

/// The dedicated BIP85 child of one Ark account: its words and its public
/// identity. It is never the parent seed. It reaches one [ArkChildConsumer] for
/// the length of one native open and goes nowhere else: not to a result, a log,
/// a field or storage.
final class ArkChild {
  /// The child's words. Strings cannot be zeroized in Dart; the scope ends when
  /// the consumer that received them settles.
  final String mnemonic;
  final Fingerprint fingerprint;

  const ArkChild._(this.mnemonic, this.fingerprint);

  @override
  String toString() => 'ArkChild(<redacted>)';
}

/// The only thing that ever receives an [ArkChild]. It is implemented once, by
/// the private adapter of the trusted Ark integration, whose native opener is
/// fixed when that adapter is built. It returns nothing: whatever the native
/// pass produces stays inside the adapter.
abstract interface class ArkChildConsumer {
  Future<void> consume(ArkChild child);
}

/// What became of a request for the child of one account.
enum ArkChildAdmission {
  /// Admitted: the consumer ran and settled.
  consumed,

  /// The account has no background access (or no membership). Nothing was read.
  notPermitted,

  /// The policy could not be read, the seed is missing or the derivation
  /// failed. Nothing reached the consumer.
  unavailable,
}

/// What the trusted Ark integration may ask of `secrets` to refresh VTXOs in
/// the background (D105).
///
/// The parent mnemonic never leaves this library. The stored entry is read
/// twice: once by `describe`, which reads and validates the words internally
/// but returns only their public description (fingerprint, kind), and once
/// inside the single `useMnemonic` call that derives the account's dedicated
/// BIP85 child (index [arkChildBip85Index], 12 English words). Only the child
/// reaches a caller, and only through [consumeChild], to a fixed
/// [ArkChildConsumer].
///
/// This library is not exported by `package:secrets/secrets.dart`. Its single
/// importer is `features/ark/lib/src/data/ark_renewal_client.dart`; an
/// architecture test fails on any other.
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
    @visibleForTesting bool multiView = multiViewSupported,
  }) async => (await openReadyInventoryStore(
    file,
    admission,
    multiView: multiView,
  )).map(ArkRenewalSecrets._);

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

  /// Hands the Ark child of [parent] to [consumer] for one native open.
  ///
  /// The policy, the seed read and the derivation happen in one admission under
  /// the inventory's write lock, which is released before [consumer] starts: no
  /// SQLite lock is held while it runs, network included. A refusal returns
  /// [ArkChildAdmission.notPermitted]; an unreadable policy, a missing seed or a
  /// failed derivation return [ArkChildAdmission.unavailable]. Only a refusal
  /// before `describe` guarantees that the parent was not read. A consumer
  /// already admitted is not interrupted by a later change.
  @useResult
  Future<ArkChildAdmission> consumeChild(
    Fingerprint parent,
    ArkChildConsumer consumer,
  ) async {
    final admitted = await _admit(parent);
    final child = admitted.child;
    if (child == null) return admitted.refusal;
    await consumer.consume(child);
    return ArkChildAdmission.consumed;
  }

  Future<({ArkChild? child, ArkChildAdmission refusal})> _admit(
    Fingerprint parent,
  ) async {
    const unavailable = (child: null, refusal: ArkChildAdmission.unavailable);
    const notPermitted = (child: null, refusal: ArkChildAdmission.notPermitted);
    try {
      return await inventoryWriteTransaction(_store.database, () async {
        await serializeInventoryWrites(_store.database);
        if (!await _permitted(_store.database, parent)) {
          return notPermitted;
        }
        final info = await _repository.describe(parent);
        if (info is! Ok<SecretInfo, SecretFailure>) {
          return unavailable;
        }
        // `describe` already read and validated the words internally; this
        // second read supplies them to the child derivation.
        final words = await _repository.useMnemonic(
          info.value,
          (m) => Deriver.bip85.mnemonic(
            m,
            language: Language.english,
            length: MnemonicLength.words12,
            index: arkChildBip85Index,
          ),
        );
        if (words is! Ok<List<String>, SecretFailure>) {
          return unavailable;
        }
        final child = await _repository.previewArkFingerprint(
          words: words.value,
        );
        if (child is! Ok<Fingerprint, SecretFailure>) {
          return unavailable;
        }
        return (
          child: ArkChild._(words.value.join(' '), child.value),
          refusal: ArkChildAdmission.consumed,
        );
      });
    } on Object {
      return unavailable;
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
