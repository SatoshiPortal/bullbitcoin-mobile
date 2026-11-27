import 'dart:async';

import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:sync/sync.dart'
    show WalletKey, WalletLifecycle, WalletRevision, WalletRevisionState;

enum OverviewCatalogueStatus {
  revoked,
  replacing,
  ready,
  empty,
  partial,
  unreadable,
  closed,
}

enum OverviewCatalogueCompleteness { complete, partial, unreadable }

enum OverviewFinancialStatus { pending, available, unreadable }

/// One publication lifetime; equality deliberately uses object identity even
/// when a later publication has the same environment or owner generation.
final class OverviewCatalogueGrant {
  final NetworkEnv environment;
  final int generation;

  OverviewCatalogueGrant._(this.environment, this.generation);
}

typedef OverviewCatalogueEntry = ({
  WalletRevision revision,
  String? label,
  bool isDefault,
  bool signsLocally,
});

typedef OverviewFinancialRequest = ({
  OverviewCatalogueGrant grant,
  WalletRevision revision,
});

/// Null is unavailable; zero is a successfully read balance.
typedef OverviewFinancialRead = ({
  OverviewFinancialRequest request,
  int? balanceSat,
});

abstract interface class OverviewFinancialReader {
  Future<OverviewFinancialRead> read(OverviewFinancialRequest request);
}

final class OverviewCatalogueRow {
  final OverviewCatalogueGrant grant;
  final OverviewCatalogueEntry entry;
  final OverviewFinancialStatus financialStatus;
  final int? balanceSat;

  OverviewCatalogueRow._(
    this.grant,
    this.entry,
    this.financialStatus,
    this.balanceSat,
  );
}

typedef OverviewCatalogueSnapshot = ({
  OverviewCatalogueStatus status,
  List<OverviewCatalogueRow> rows,
});

typedef OverviewWalletSelection = ({
  WalletKey key,
  String? label,
  bool isDefault,
});

/// Joins admitted catalogue entries with read-only financial values without
/// imposing a second ordering or granting membership from a Sync revision.
final class OverviewCatalogue {
  final OverviewFinancialReader _reader;
  final _changes = StreamController<void>.broadcast();
  final _rows = <WalletKey, OverviewCatalogueRow>{};
  OverviewCatalogueGrant? _grant;
  var _status = OverviewCatalogueStatus.revoked;
  var _published = false;

  OverviewCatalogue(this._reader);

  OverviewCatalogueSnapshot get snapshot =>
      (status: _status, rows: List.unmodifiable(_rows.values));

  /// Notifications carry no captured data: observers read [snapshot] after
  /// each notification, never an enqueued pre-revocation copy.
  Stream<void> get changes => _changes.stream;

  OverviewCatalogueGrant? replacing(NetworkEnv environment, int generation) {
    if (_status == OverviewCatalogueStatus.closed) return null;
    final grant = OverviewCatalogueGrant._(environment, generation);
    _reset(OverviewCatalogueStatus.replacing, grant);
    return grant;
  }

  void revoke(OverviewCatalogueGrant grant) {
    if (identical(_grant, grant)) _reset(OverviewCatalogueStatus.revoked, null);
  }

  void publish(
    OverviewCatalogueGrant grant,
    OverviewCatalogueCompleteness completeness,
    Iterable<OverviewCatalogueEntry> entries,
  ) {
    if (!identical(_grant, grant) || _published) return;
    _published = true;
    if (completeness == OverviewCatalogueCompleteness.unreadable) {
      _status = OverviewCatalogueStatus.unreadable;
      _changes.add(null);
      return;
    }

    var partial = completeness == OverviewCatalogueCompleteness.partial;
    final duplicates = <WalletKey>{};
    for (final entry in entries) {
      final key = entry.revision.key;
      if (key.network.env != grant.environment || duplicates.contains(key)) {
        partial = true;
        continue;
      }
      if (_rows.containsKey(key)) {
        _rows.remove(key);
        duplicates.add(key);
        partial = true;
        continue;
      }
      _rows[key] = _pending(grant, entry);
    }
    _status = partial
        ? OverviewCatalogueStatus.partial
        : _rows.isEmpty
        ? OverviewCatalogueStatus.empty
        : OverviewCatalogueStatus.ready;
    _changes.add(null);
    for (final row in _rows.values.toList()) {
      unawaited(_read(row));
    }
  }

  void revised(OverviewCatalogueGrant grant, WalletRevisionState revision) {
    if (!identical(_grant, grant)) return;
    final stamp = revision.stamp;
    final row = _rows[stamp.key];
    if (row == null) return;
    final current = row.entry.revision;
    if (stamp.generation != current.generation ||
        stamp.revision <= current.revision) {
      return;
    }
    if (revision.lifecycle != WalletLifecycle.active) {
      _rows.remove(stamp.key);
      _status = OverviewCatalogueStatus.partial;
      _changes.add(null);
      return;
    }
    final next = _pending(grant, (
      revision: stamp,
      label: row.entry.label,
      isDefault: row.entry.isDefault,
      signsLocally: row.entry.signsLocally,
    ));
    _rows[stamp.key] = next;
    _changes.add(null);
    unawaited(_read(next));
  }

  /// Validate at tap time, not when the card was originally built.
  OverviewWalletSelection? selectLocal(OverviewCatalogueRow row) {
    final entry = row.entry;
    final current = _rows[entry.revision.key];
    if (!identical(_grant, row.grant) ||
        current?.entry.revision != entry.revision ||
        !entry.signsLocally) {
      return null;
    }
    return (
      key: entry.revision.key,
      label: entry.label,
      isDefault: entry.isDefault,
    );
  }

  Future<void> close() async {
    if (_status == OverviewCatalogueStatus.closed) return;
    _reset(OverviewCatalogueStatus.closed, null);
    await _changes.close();
  }

  void _reset(OverviewCatalogueStatus status, OverviewCatalogueGrant? grant) {
    _grant = grant;
    _published = false;
    _rows.clear();
    _status = status;
    _changes.add(null);
  }

  OverviewCatalogueRow _pending(
    OverviewCatalogueGrant grant,
    OverviewCatalogueEntry entry,
  ) => OverviewCatalogueRow._(
    grant,
    entry,
    OverviewFinancialStatus.pending,
    null,
  );

  Future<void> _read(OverviewCatalogueRow row) async {
    final revision = row.entry.revision;
    final request = (grant: row.grant, revision: revision);
    int? balance;
    try {
      final result = await _reader.read(request);
      if (result.request != request) return;
      balance = result.balanceSat;
    } on Exception {
      balance = null;
    }
    if (!identical(_grant, row.grant) || !identical(_rows[revision.key], row)) {
      return;
    }
    _rows[revision.key] = OverviewCatalogueRow._(
      row.grant,
      row.entry,
      balance == null
          ? OverviewFinancialStatus.unreadable
          : OverviewFinancialStatus.available,
      balance,
    );
    _changes.add(null);
  }
}
