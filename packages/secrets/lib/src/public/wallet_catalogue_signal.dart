part of 'secrets_inventory.dart';

/// An exact foreground grant and its independent wallet catalogue generation.
/// This is an observation stamp, not a new permission.
final class WalletCatalogueStamp {
  final SessionToken grant;
  final int generation;

  const WalletCatalogueStamp._(this.grant, this.generation);
}

/// Read-only invalidation signal. Events carry no wallet or grant data;
/// capture again after an event and validate after every asynchronous read.
final class WalletCatalogueSignal {
  final SessionAuthority _authority;
  final _changes = StreamController<void>.broadcast();
  late final StreamSubscription<SessionToken?> _sessionChanges;
  var _generation = 0;
  var _closed = false;

  WalletCatalogueSignal._(this._authority) {
    _sessionChanges = _authority.changes.listen((_) => _changes.add(null));
  }

  WalletCatalogueStamp? capture() {
    final grant = _authority.current;
    return _closed || grant == null
        ? null
        : WalletCatalogueStamp._(grant, _generation);
  }

  bool isCurrent(WalletCatalogueStamp stamp) =>
      !_closed &&
      _authority.isCurrent(stamp.grant) &&
      stamp.generation == _generation;

  Stream<void> get changes => _changes.stream;

  void _committed() {
    if (_closed) return;
    _generation++;
    _changes.add(null);
  }

  Future<void> _close() async {
    _closed = true;
    await _sessionChanges.cancel();
    // A paused observer cannot hold the inventory database open.
    unawaited(_changes.close());
  }
}
