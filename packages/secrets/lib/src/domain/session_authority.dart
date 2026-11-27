import 'dart:async';

import 'package:meta/meta.dart';

/// The proof that one authentication happened. It names the view that was
/// opened and the generation of that opening; it carries no key material.
///
/// Only a [SessionAuthority] makes one, and only when the inventory has
/// authenticated. A handle that captured a token stops working the moment the
/// authority moves on, including after a later unlock: that opening is a new
/// generation, not the one the handle was issued in.
final class SessionToken {
  /// The view the authentication opened.
  final String activeView;

  /// Increases on every grant. Never reused within a process.
  final int generation;

  const SessionToken._(this.activeView, this.generation);

  @override
  String toString() => 'SessionToken($activeView, #$generation)';
}

/// Who may use secrets right now.
///
/// One authority is built by the composition before the inventory and shared
/// by it and by `Secrets`. Locking revokes the current token before anything
/// waits, so no new operation starts and no handle already handed out can
/// reach key material again. A killed process restarts locked.
final class SessionAuthority {
  SessionToken? _current;
  var _generation = 0;
  final _changes = StreamController<SessionToken?>.broadcast(sync: true);

  SessionAuthority();

  /// The token of the session that may use secrets; null while locked.
  SessionToken? get current => _current;

  /// Every grant and revocation, in order.
  Stream<SessionToken?> get changes => _changes.stream;

  /// Whether [token] is the live session: same view and same generation.
  bool isCurrent(SessionToken token) {
    final live = _current;
    return live != null &&
        live.generation == token.generation &&
        live.activeView == token.activeView;
  }

  /// Opens a session for [view]. Called by the inventory after authentication.
  @internal
  SessionToken grant(String view) {
    final token = SessionToken._(view, ++_generation);
    _current = token;
    _changes.add(token);
    return token;
  }

  /// Closes the session. Idempotent. Called by the inventory on lock.
  @internal
  void revoke() {
    if (_current == null) return;
    _current = null;
    _changes.add(null);
  }
}

/// One session as seen by an operation or a handle: the authority and the
/// token captured when the work began. It never refreshes itself.
final class SessionScope {
  final SessionAuthority _authority;
  final SessionToken token;

  @internal
  const SessionScope(this._authority, this.token);

  /// Whether the session this scope was taken in is still the live one.
  bool get isCurrent => _authority.isCurrent(token);
}
