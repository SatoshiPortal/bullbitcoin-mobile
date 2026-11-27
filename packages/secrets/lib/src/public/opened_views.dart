part of 'secrets_inventory.dart';

/// The outcome of one authentication: the attempt it counted, and the views it
/// opened when it was accepted.
final class ViewAuthentication {
  final AccessAttempt attempt;

  /// Null unless [attempt] was accepted.
  final OpenedViews? views;

  const ViewAuthentication._(this.attempt, this.views);
}

/// The views the authentications of one session opened, and the only way to
/// choose which one is in use. It lives until the inventory locks.
///
/// Holding a view id is not holding the view: [activate] refuses an id this
/// session never opened, whether or not such a view exists, and a value kept
/// across a lock is refused even after the next unlock.
final class OpenedViews {
  final SecretsInventory _inventory;
  final int _epoch;

  const OpenedViews._(this._inventory, this._epoch);

  /// The views opened so far, by name. Empty once the session is over.
  List<ViewSummary> get views =>
      _inventory._epoch == _epoch ? _inventory._openedViews : const [];

  /// Puts [id] in use. The previous view's handles and pending reads stop
  /// working at once: this opens a new session generation.
  @useResult
  Future<Result<ViewSummary, SecretFailure>> activate(ViewId id) async {
    if (_inventory._pendingDrain != null) {
      return const Err(inventoryLockedFailure);
    }
    if (_inventory._epoch != _epoch) {
      return const Err(inventorySessionChangedFailure);
    }
    for (final view in _inventory._openedViews) {
      if (view.id == id) {
        // Reads and writes still running for the previous view must not
        // publish into this one.
        _inventory._session++;
        _inventory._startSession(view);
        return Ok(view);
      }
    }
    return const Err(viewNotOpenFailure);
  }
}
