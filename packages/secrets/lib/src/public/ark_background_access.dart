import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:legacy_storage/coordination.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../data/backup_guard.dart';
import '../data/inventory_store.dart';
import '../data/ready_inventory_store.dart';
import '../data/secrets_database.dart';
import '../domain/domain.dart';

/// BIP85 index of the Ark child derived from a wallet seed.
const arkChildBip85Index = 11811;

/// What the headless Ark task may know about a wallet seed (D92): a yes or a
/// no, never the seed.
///
/// It reads no seed, derives nothing and hands out no words, handle or
/// callback. The task asks whether a view still lets Ark show reminders for a
/// parent while the app is locked. Renewal is not decided here: it needs the
/// seed, so it does not run headless at all (see `DisabledRenewalChildProvider`
/// in `bull_ark`); an architecture test keeps this library free of any
/// operation that delivers words.
///
/// Opened under the shared runtime lease like [BackgroundWalletDescriptors].
final class ArkBackgroundAccess {
  final InventoryStore _store;

  ArkBackgroundAccess._(this._store);

  @useResult
  static Future<Result<ArkBackgroundAccess, DatabaseOpenFailure>> open({
    required File file,
    required RuntimeAdmission admission,
  }) async => (await openReadyInventoryStore(
    file,
    admission,
  )).map(ArkBackgroundAccess._);

  /// Whether Ark may still notify for [parent] while locked, read afresh under
  /// the inventory's write lock (a PIN set concurrently is serialized with
  /// this read):
  ///
  /// 1. [parent] belongs to at least one view with background access enabled;
  ///    no membership never satisfies "every view is unprotected";
  /// 2. no view that contains [parent] has a credential.
  ///
  /// An unreadable policy is a refusal.
  @useResult
  Future<bool> mayNotify(Fingerprint parent) async {
    try {
      return await inventoryWriteTransaction(_store.database, () async {
        await serializeInventoryWrites(_store.database);
        return _permitted(_store.database, parent);
      });
    } on Object {
      return false;
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
