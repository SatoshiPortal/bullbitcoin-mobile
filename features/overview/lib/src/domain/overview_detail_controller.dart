import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show WalletSigner;
import 'package:sync/sync.dart' show WalletKey, WalletRevision;

import 'overview_catalogue.dart';

/// A selected membership and its currently available financial receipt.
final class OverviewDetailWallet {
  const OverviewDetailWallet._(this._row, this._owner, this._epoch);

  final OverviewCatalogueRow _row;
  final OverviewDetailController _owner;
  final int _epoch;

  WalletKey get key => _row.entry.key;
  ScriptType get scriptType => _row.entry.script;
  WalletSigner get signer => _row.entry.signer;
  String? get label => _row.entry.label;
  bool get isDefault => _row.entry.isDefault;
  BigInt? get balanceSat => _row.balanceSat;
  WalletRevision? get revision => _row.revision;
  bool get isCurrent =>
      !_owner._disposed && _owner._epoch == _epoch && _row.isCurrent;

  /// Legacy wallet IDs append this suffix only for the Regtest networks.
  String get origin {
    final id = key.id;
    return key.network.env == NetworkEnv.regtest && id.endsWith(':regtest')
        ? id.substring(0, id.length - ':regtest'.length)
        : id;
  }
}

/// Observes a key across catalogue epochs; financial receipts never add it.
final class OverviewDetailController extends ChangeNotifier
    implements ValueListenable<OverviewDetailWallet?> {
  OverviewDetailController({
    required OverviewCatalogue catalogue,
    required WalletKey key,
  }) : this._(
         catalogue: catalogue,
         walletId: key.id,
         select: (row) => row.entry.key == key,
       );

  /// Resolves the route identity only once its unique catalogue row exists.
  /// It never guesses a network while the initial inventory read is pending.
  OverviewDetailController.byId({
    required OverviewCatalogue catalogue,
    required String walletId,
  }) : this._(
         catalogue: catalogue,
         walletId: walletId,
         select: (row) => row.entry.key.id == walletId,
       );

  OverviewDetailController._({
    required this.catalogue,
    required this.walletId,
    required this._select,
  }) {
    _subscription = catalogue.changes.listen((_) => _update());
    _update();
  }

  final OverviewCatalogue catalogue;
  final String walletId;
  final bool Function(OverviewCatalogueRow) _select;
  late final StreamSubscription<void> _subscription;
  OverviewCatalogueRow? _admission;
  OverviewDetailWallet? _wallet;
  int _epoch = 0;
  bool _disposed = false;

  @override
  OverviewDetailWallet? get value {
    final current = _wallet;
    return current != null && current.isCurrent ? current : null;
  }

  void _update() {
    if (_disposed) return;
    final admission = _admission;
    final rows = catalogue.snapshot.rows.where(_select);
    final selected = rows.length == 1 ? rows.single : null;
    if (admission == null
        ? selected != null
        : selected == null || !admission.sameMembership(selected)) {
      _epoch++;
    }
    _admission = selected;
    _wallet = selected == null
        ? null
        : OverviewDetailWallet._(selected, this, _epoch);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
