import 'dart:io';

import 'package:legacy_storage/coordination.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../data/ark_notify_policy.dart';
import '../data/inventory_store.dart';
import '../data/ready_inventory_store.dart';
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

  /// Whether Ark may still notify for [parent] while locked; see
  /// [arkNotifyPermitted] for the rule.
  @useResult
  Future<bool> mayNotify(Fingerprint parent) =>
      arkNotifyPermitted(_store.database, parent);

  Future<void> close() => _store.close();
}
