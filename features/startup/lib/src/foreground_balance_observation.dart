part of 'foreground_balance_startup.dart';

/// Identity for one admitted environment and catalogue. Null environment
/// means the committed setting could not be read.
final class ForegroundBalanceContext {
  final NetworkEnv? environment;
  final _Candidate _candidate;

  const ForegroundBalanceContext._(this.environment, this._candidate);
}

/// Exact native revision installed by Startup, not permission to spend.
final class ForegroundBalanceReceipt {
  final ForegroundBalanceContext _context;
  final WalletRevision revision;

  const ForegroundBalanceReceipt._(this._context, this.revision);
}

/// Passive access to the existing producer. Nothing here queues or opens Sync.
final class ForegroundBalanceObservation {
  final ForegroundBalanceStartup _owner;

  const ForegroundBalanceObservation._(this._owner);

  ForegroundBalanceContext? get current {
    final context = _owner._context;
    return context != null && isCurrent(context) ? context : null;
  }

  bool isCurrent(ForegroundBalanceContext context) =>
      identical(_owner._context, context) &&
      _owner._current(context._candidate);

  Stream<void> get changes => _owner._changes.stream;

  ForegroundBalanceReceipt? receipt(
    ForegroundBalanceContext context,
    WalletKey key,
  ) => isCurrent(context) ? _owner._receipts[key] : null;

  /// Re-read on every use; a second SQLite connection can invalidate a stamp
  /// without the current isolate receiving an event.
  BigInt? read(ForegroundBalanceReceipt receipt) {
    final context = receipt._context;
    final key = receipt.revision.key;
    if (!identical(this.receipt(context, key), receipt)) return null;
    final result = _owner._readRetained?.call(
      context._candidate.catalogue,
      receipt.revision,
    );
    return switch (result) {
      Ok(:final value) when identical(this.receipt(context, key), receipt) =>
        value,
      _ => null,
    };
  }
}
