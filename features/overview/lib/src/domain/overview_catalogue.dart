import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart'
    show SecretFailure, WalletInventory, WalletSelection, WalletSigner;
import 'package:startup/balances.dart';
import 'package:sync/sync.dart' show WalletKey, WalletRevision;

enum OverviewCatalogueStatus {
  revoked,
  replacing,
  ready,
  empty,
  partial,
  unreadable,
  closed,
}

typedef OverviewCatalogueEntry = ({
  WalletKey key,
  ScriptType script,
  WalletSigner signer,
  String? label,
  bool isDefault,
});

typedef OverviewWalletSelection = ({
  WalletKey key,
  String? label,
  bool isDefault,
});

final class OverviewCatalogueRow {
  final OverviewCatalogueEntry entry;
  final OverviewCatalogue _owner;
  final ForegroundBalanceContext _context;
  final ForegroundBalanceReceipt? _receipt;

  const OverviewCatalogueRow._(
    this.entry,
    this._owner,
    this._context,
    this._receipt,
  );

  /// An old row can outlive an event. Neither accessor returns stale money.
  BigInt? get balanceSat => _owner._read(this);
  WalletRevision? get revision =>
      balanceSat == null ? null : _receipt?.revision;
}

typedef OverviewCatalogueSnapshot = ({
  OverviewCatalogueStatus status,
  List<OverviewCatalogueRow> rows,
});

/// One join of admitted membership and already-produced financial receipts.
/// No native change can add or remove an inventory row.
final class OverviewCatalogue {
  final ForegroundBalanceObservation _balances;
  final Future<Result<WalletSelection, SecretFailure>> Function(Network)
  _membership;
  final _changes = StreamController<void>.broadcast();
  late final StreamSubscription<void> _subscription;
  ForegroundBalanceContext? _context;
  Future<void>? _loading;
  Future<void>? _closing;
  var _closed = false;
  var _status = OverviewCatalogueStatus.revoked;
  var _entries = <WalletKey, OverviewCatalogueEntry>{};

  OverviewCatalogue.mount({
    required this._balances,
    required WalletInventory inventory,
  }) : _membership = inventory.walletsForNetwork {
    _subscription = _balances.changes.listen((_) => _woken());
    _woken();
  }

  /// Subscribers always re-read; no event carries membership or money.
  Stream<void> get changes => _changes.stream;

  OverviewCatalogueSnapshot get snapshot {
    final current = _balances.current;
    if (_closed || current == null || !identical(current, _context)) {
      return (
        status: _closed
            ? OverviewCatalogueStatus.closed
            : current == null
            ? OverviewCatalogueStatus.revoked
            : OverviewCatalogueStatus.replacing,
        rows: const [],
      );
    }
    return (
      status: _status,
      rows: List.unmodifiable(
        _entries.values.map(
          (entry) => OverviewCatalogueRow._(
            entry,
            this,
            current,
            _balances.receipt(current, entry.key),
          ),
        ),
      ),
    );
  }

  BigInt? _read(OverviewCatalogueRow row) {
    if (_closed ||
        !identical(_context, row._context) ||
        !_balances.isCurrent(row._context) ||
        _entries[row.entry.key] != row.entry) {
      return null;
    }
    final receipt = row._receipt;
    return receipt == null ? null : _balances.read(receipt);
  }

  /// Conservative handoff: require a live local receipt at the point of use.
  /// The result is not a spend or detail-route authorization.
  OverviewWalletSelection? selectLocal(OverviewCatalogueRow row) {
    final entry = row.entry;
    if (!identical(row._owner, this) ||
        entry.signer != WalletSigner.local ||
        _read(row) == null) {
      return null;
    }
    return (key: entry.key, label: entry.label, isDefault: entry.isDefault);
  }

  void _woken() {
    if (_closed) return;
    final current = _balances.current;
    if (!identical(_context, current)) {
      _context = current;
      _entries = {};
      _status = current == null
          ? OverviewCatalogueStatus.revoked
          : OverviewCatalogueStatus.replacing;
    }
    _changes.add(null);
    _schedule();
  }

  void _schedule() {
    final context = _context;
    if (_closed ||
        context == null ||
        !_balances.isCurrent(context) ||
        _loading != null ||
        _status != OverviewCatalogueStatus.replacing) {
      return;
    }
    _loading = Future<void>.microtask(() async {
      try {
        await _load(context);
      } finally {
        _loading = null;
        _schedule();
      }
    });
  }

  Future<void> _load(ForegroundBalanceContext context) async {
    bool current() =>
        !_closed &&
        identical(_context, context) &&
        _balances.isCurrent(context);
    if (!current()) return;
    final List<Network> networks = switch (context.environment) {
      NetworkEnv.mainnet => [BitcoinNetwork.mainnet, LiquidNetwork.mainnet],
      NetworkEnv.testnet => [BitcoinNetwork.testnet, LiquidNetwork.testnet],
      NetworkEnv.regtest => [BitcoinNetwork.regtest, LiquidNetwork.regtest],
      _ => <Network>[],
    };
    final entries = <OverviewCatalogueEntry>[];
    var complete = true;
    var readable = 0;
    for (final network in networks) {
      final result = await _membership(network);
      if (!current()) return;
      switch (result) {
        case Err():
          complete = false;
        case Ok(:final value):
          readable++;
          complete &= value.isComplete;
          for (final wallet in value.wallets) {
            if (wallet.network != network) {
              complete = false;
              continue;
            }
            entries.add((
              key: WalletKey(id: wallet.id, network: wallet.network),
              script: wallet.scriptType,
              signer: wallet.signer,
              label: wallet.label,
              isDefault: wallet.isDefault,
            ));
          }
      }
    }
    if (!current()) return;
    int rank(OverviewCatalogueEntry entry) => !entry.isDefault
        ? 2
        : entry.key.network is BitcoinNetwork
        ? 0
        : 1;
    entries.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      final byId = a.key.id.compareTo(b.key.id);
      if (byId != 0) return byId;
      return (a.key.network is BitcoinNetwork ? 0 : 1).compareTo(
        b.key.network is BitcoinNetwork ? 0 : 1,
      );
    });
    final duplicates = <WalletKey>{};
    for (final entry in entries) {
      if (duplicates.contains(entry.key)) continue;
      if (_entries.containsKey(entry.key)) {
        _entries.remove(entry.key);
        duplicates.add(entry.key);
        complete = false;
      } else {
        _entries[entry.key] = entry;
      }
    }
    _status = readable == 0
        ? OverviewCatalogueStatus.unreadable
        : !complete
        ? OverviewCatalogueStatus.partial
        : _entries.isEmpty
        ? OverviewCatalogueStatus.empty
        : OverviewCatalogueStatus.ready;
    _changes.add(null);
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    _entries.clear();
    _changes.add(null);
    await _subscription.cancel();
    await _loading;
    unawaited(_changes.close());
  }
}
