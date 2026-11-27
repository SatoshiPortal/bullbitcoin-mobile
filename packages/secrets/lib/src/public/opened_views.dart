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

  /// Administration of the views this session opened.
  ViewAdministration get administration =>
      ViewAdministration._(_inventory, this);

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
        await _inventory._startSession(view);
        return Ok(view);
      }
    }
    return const Err(viewNotOpenFailure);
  }
}

/// Changes to the set of views. Every view it names must be one the session
/// opened, and what a new view holds comes from the view in use.
final class ViewAdministration {
  final SecretsInventory _inventory;
  final OpenedViews _views;

  const ViewAdministration._(this._inventory, this._views);

  bool _opened(ViewId id) => _views.views.any((view) => view.id == id);

  /// Makes a view with no PIN and puts it among the opened views. [secrets]
  /// and [publicWallets] must belong to the view in use.
  @useResult
  Future<Result<ViewSummary, SecretFailure>> create({
    required String name,
    Set<Fingerprint> secrets = const {},
    Set<String> publicWallets = const {},
  }) async {
    final result = await _inventory._inSession(
      (_, view) async => (await _inventory._administration.create(
        source: view,
        name: name,
        secrets: secrets,
        publicWallets: publicWallets,
      )).map((summary) => summary),
      preserveCommittedCommand: true,
    );
    if (result case Ok(:final value)) _inventory._mergeOpened([value]);
    return result;
  }

  @useResult
  Future<Result<void, SecretFailure>> rename(ViewId id, String name) async {
    if (!_opened(id)) return const Err(viewNotOpenFailure);
    final result = await _inventory._inSession(
      (_, _) => _inventory._administration.rename(id.value, name),
      preserveCommittedCommand: true,
    );
    if (result is Ok) {
      _inventory._openedViews = List.unmodifiable([
        for (final view in _inventory._openedViews)
          view.id == id
              ? ViewSummary(
                  id: view.id,
                  name: name.trim(),
                  isProtected: view.isProtected,
                  backgroundEnabled: view.backgroundEnabled,
                )
              : view,
      ]);
    }
    return result;
  }

  /// Deletes a view other than the one in use, and never the last one.
  @useResult
  Future<Result<void, SecretFailure>> delete(ViewId id) async {
    if (!_opened(id)) return const Err(viewNotOpenFailure);
    final inUse = _inventory._authority.current?.activeView;
    if (inUse == id.value) return const Err(viewInUseFailure);
    final result = await _inventory._inSession(
      (_, _) => _inventory._administration.delete(id.value),
      preserveCommittedCommand: true,
    );
    if (result is Ok) {
      _inventory._openedViews = List.unmodifiable([
        for (final view in _inventory._openedViews)
          if (view.id != id) view,
      ]);
    }
    return result;
  }

  /// Adds a seed of the view in use to another opened view.
  @useResult
  Future<Result<void, SecretFailure>> attach(
    Fingerprint secret, {
    required ViewId to,
  }) async {
    if (!_opened(to)) return const Err(viewNotOpenFailure);
    return _inventory._inSession(
      (_, view) => _inventory._administration.attach(
        source: view,
        target: to.value,
        secret: secret,
      ),
      preserveCommittedCommand: true,
    );
  }

  /// Removes a seed from the view in use when another view still holds it.
  @useResult
  Future<Result<void, SecretFailure>> detach(Fingerprint secret) =>
      _inventory._inSession(
        (_, view) =>
            _inventory._administration.detach(view: view, secret: secret),
        preserveCommittedCommand: true,
      );
}
