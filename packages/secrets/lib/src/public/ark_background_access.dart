import 'dart:io';

import 'package:legacy_storage/coordination.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../data/ark_notify_policy.dart';
import '../data/inventory_store.dart';
import '../data/ready_inventory_store.dart';
import '../data/view_format.dart' show multiViewSupported;
import '../domain/domain.dart';

/// BIP85 index of the Ark child derived from a wallet seed.
const arkChildBip85Index = 11811;

/// What the headless Ark task may know about whether a view lets Ark show
/// reminders (D92, D105): a yes or a no, never a seed.
///
/// It reads no seed, derives nothing and hands out no words, handle or
/// callback. The task asks whether a view still lets Ark notify for a parent
/// while the app is locked: background access enabled and no PIN-protected view
/// holding the seed. This veto is the reminders' own. The background refresh of
/// VTXOs is decided elsewhere (D105): it uses only the account's dedicated
/// BIP85 child, so a PIN does not refuse it. That path is the restricted
/// `package:secrets/ark_renewal.dart` library, and an architecture test keeps
/// this one free of any operation that delivers words.
///
/// Opened under the shared runtime lease like [BackgroundWalletDescriptors].
final class ArkBackgroundAccess {
  final InventoryStore _store;

  ArkBackgroundAccess._(this._store);

  @useResult
  static Future<Result<ArkBackgroundAccess, DatabaseOpenFailure>> open({
    required File file,
    required RuntimeAdmission admission,
    @visibleForTesting bool multiView = multiViewSupported,
  }) async => (await openReadyInventoryStore(
    file,
    admission,
    multiView: multiView,
  )).map(ArkBackgroundAccess._);

  /// Whether Ark may still notify for [parent] while locked; see
  /// [arkNotifyPermitted] for the rule.
  @useResult
  Future<bool> mayNotify(Fingerprint parent) =>
      arkNotifyPermitted(_store.database, parent);

  Future<void> close() => _store.close();
}
