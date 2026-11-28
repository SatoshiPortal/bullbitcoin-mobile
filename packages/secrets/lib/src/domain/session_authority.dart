import 'dart:async';

import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

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

  /// Increases on every grant from the same authority.
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
  Future<Set<String>?> Function(SessionToken)? _memberships;
  final _madeInSession = <String>{};
  final _changes = StreamController<SessionToken?>.broadcast(sync: true);

  @internal
  late final ForegroundSession foreground = ForegroundSession._(this);

  SessionAuthority();

  /// The token of the session that may use secrets; null while locked.
  SessionToken? get current => _current;

  /// Every grant and revocation, in order.
  Stream<SessionToken?> get changes => _changes.stream;

  /// Gives the authority the way to ask which seeds a view holds. Bound once by
  /// the inventory that owns the memberships; the answer is null while the file
  /// holds a single view, where nothing is hidden from anything.
  @internal
  void bindMemberships(Future<Set<String>?> Function(SessionToken) read) {
    _memberships = read;
  }

  /// Whether the session of [token] may find, list, test for or use the seed
  /// [id]: it belongs to the view in use, or this session just made or
  /// received it and has not registered it yet.
  @internal
  Future<bool> mayUse(SessionToken token, Fingerprint id) async {
    final visible = await visibleTo(token);
    return visible == null || visible.contains(id.hex);
  }

  /// The seeds [token]'s view holds, or null when every seed is visible.
  @internal
  Future<Set<String>?> visibleTo(SessionToken token) async {
    if (!isCurrent(token)) return <String>{};
    final read = _memberships;
    final members = read == null ? null : await read(token);
    if (members == null) return null;
    if (!isCurrent(token)) return <String>{};
    return {...members, ..._madeInSession};
  }

  /// Records a seed the session just generated, imported or proved the words
  /// of, so it stays usable until the view registers it.
  @internal
  void noteMade(SessionToken token, Fingerprint id) {
    if (isCurrent(token)) _madeInSession.add(id.hex);
  }

  /// Whether [token] is the exact live grant made by this authority.
  bool isCurrent(SessionToken token) => identical(_current, token);

  /// Opens a session for [view]. Called by the inventory after authentication.
  @internal
  SessionToken grant(String view) {
    final token = SessionToken._(view, ++_generation);
    _madeInSession.clear();
    _current = token;
    _changes.add(token);
    return token;
  }

  /// Closes the session. Idempotent. Called by the inventory on lock.
  @internal
  void revoke() {
    if (_current == null) return;
    _madeInSession.clear();
    _current = null;
    _changes.add(null);
  }
}

/// Read-only observation of the foreground grant from one authority.
final class ForegroundSession {
  final SessionAuthority _authority;

  const ForegroundSession._(this._authority);

  /// The live grant, or null while locked.
  SessionToken? capture() => _authority.current;

  /// Whether [token] is still this authority's live grant.
  bool isCurrent(SessionToken token) => _authority.isCurrent(token);

  /// Replacements and revocations, in order. Use [capture] for initial state.
  Stream<SessionToken?> get changes => _authority.changes;
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
