import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:drift/drift.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import '../crypto/access_verifier.dart';
import '../domain/access_attempt.dart';
import '../domain/domain.dart';
import 'backup_guard.dart';
import 'boundary.dart';
import 'encrypted_database.dart' show databaseFileProblemOf;
import 'secrets_database.dart';
import 'secrets_database.drift.dart';

/// Access authority over every view. Comparison and rate limiting commit together.
final class AccessRepository {
  static const _maxEpoch = 8640000000000000;
  static const _attemptIncrementMs = 30000;

  final SecretsDatabase _database;
  final BackupGuard _guard;
  final Stopwatch _cooldown = Stopwatch();
  ({int attempts, int? until})? _cooldownState;

  @internal
  AccessRepository(this._database, this._guard);

  /// Whether any view requires a credential.
  Future<Result<bool, SecretFailure>> isProtected() =>
      boundary(_anyCredential, orElse: FetchSecretFailure.new);

  /// The read that opens an admitted inventory. Unlike [isProtected] its
  /// failure keeps the engine's cause, so the caller can tell damaged data
  /// from contention or an access error.
  Future<Result<bool, DatabaseOpenFailure>> protectionAtOpen() async {
    try {
      return Ok(await _anyCredential());
    } on SqliteException catch (error) {
      return Err(DatabaseFileUnavailable(databaseFileProblemOf(error)));
    } on Exception {
      // Not proof that the data is damaged.
      return const Err(
        DatabaseFileUnavailable(DatabaseFileProblem.inaccessible),
      );
    }
  }

  Future<Result<AccessAttempt, SecretFailure>> status() => boundary(() async {
    final state = await _state();
    return _attempt(state, accepted: false);
  }, orElse: FetchSecretFailure.new);

  /// The view opened last, or null. Callers use it only among opened views.
  /// A failed read is a failure: it is not hidden as "no memory".
  Future<Result<String?, SecretFailure>> lastView() => boundary(
    () async => (await _state()).lastViewId,
    orElse: FetchSecretFailure.new,
  );

  /// Remembers [id] for the next opening. The opening does not depend on it,
  /// so a failure is returned for the caller to log, never thrown.
  Future<Result<void, SecretFailure>> rememberView(String id) =>
      boundary(() async {
        await _database.customStatement(
          'UPDATE access_state SET last_view_id = ? WHERE singleton = 1',
          [id],
        );
      }, orElse: StoreSecretFailure.new);

  /// The views a session may open when no view requires a credential: all of
  /// them, with no attempt counted. A protected view makes this a refusal.
  Future<Result<List<ViewSummary>?, SecretFailure>> openWithoutCredential() =>
      boundary(() async {
        final views = await _views();
        if (views.any((view) => view.credentialId != null)) return null;
        return _summaries(views);
      }, orElse: FetchSecretFailure.new);

  /// One authentication against every credential at once.
  ///
  /// One guess counts as one attempt however many credentials exist: every
  /// distinct credential is evaluated, and the counter moves once if none
  /// matches. The views opened are those protected by a credential that
  /// matched, plus views with no credential. Presenting a view that needs no
  /// credential is not a success: a protected installation opens nothing unless
  /// a credential matches. The counter returns to zero only when every
  /// credential matched, so a known PIN cannot reset the attempts spent
  /// guessing another.
  Future<
    Result<({AccessAttempt attempt, List<ViewSummary> opened}), SecretFailure>
  >
  authenticate(String candidate) => boundary(
    () => _database.transaction(() async {
      // Take the write lock before reading. Two SQLite connections must never
      // evaluate a guess against the same attempt count.
      final state = await _stateForUpdate();
      final blocked = _attempt(state, accepted: false);
      if (blocked.remaining > Duration.zero) {
        return (attempt: blocked, opened: const <ViewSummary>[]);
      }
      final views = await _views();
      final credentialIds = {for (final view in views) ?view.credentialId};
      if (credentialIds.isEmpty) {
        return (
          attempt: _attempt(state, accepted: true),
          opened: _summaries(views),
        );
      }
      final matched = <String>{};
      for (final id in credentialIds) {
        final credential = await _credentialRow(id);
        final output = await AccessVerifier.derive(candidate, credential.salt);
        if (AccessVerifier.equals(output, credential.verifier)) matched.add(id);
        output.fillRange(0, output.length, 0);
      }
      final accepted = matched.isNotEmpty;
      final everyCredential = matched.length == credentialIds.length;
      final AccessStateRow next;
      if (!accepted) {
        final attempts = state.failedAttempts.clamp(0, _maxEpoch) + 1;
        final cooldown = _cooldownMilliseconds(attempts);
        final until = cooldown == 0
            ? null
            : (DateTime.now().millisecondsSinceEpoch + cooldown).clamp(
                -_maxEpoch,
                _maxEpoch,
              );
        next = state.copyWith(
          failedAttempts: attempts,
          lockedUntil: Value(until),
        );
      } else if (everyCredential) {
        next = state.copyWith(
          failedAttempts: 0,
          lockedUntil: const Value(null),
        );
      } else {
        next = state;
      }
      if (!identical(next, state)) {
        await _database.update(_database.accessState).replace(next);
      }
      return (
        attempt: _attempt(next, accepted: accepted),
        opened: accepted
            ? _summaries([
                for (final view in views)
                  if (view.credentialId == null ||
                      matched.contains(view.credentialId))
                    view,
              ])
            : const <ViewSummary>[],
      );
    }),
    orElse: FetchSecretFailure.new,
  );

  Future<Result<void, SecretFailure>> setBackgroundEnabled(
    bool enabled,
    String viewId,
  ) => boundary(
    () => guardedTransaction(_database, () async {
      final view = await _view(viewId);
      await (_database.update(_database.views)
            ..where((v) => v.id.equals(view.id)))
          .write(ViewsCompanion(backgroundEnabled: Value(enabled)));
    }),
    orElse: StoreSecretFailure.new,
  );

  /// The secrets of the active view that still lack a tested backup. Read only:
  /// a decision to protect is taken again under the write lock.
  Future<Result<List<Fingerprint>, SecretFailure>> unbackedSecrets(
    String view,
  ) async {
    final secrets = await boundary(
      () => viewSecrets(_database, view),
      orElse: FetchSecretFailure.new,
    );
    return switch (secrets) {
      Ok(:final value) => _guard.missing(value),
      Err(:final failure) => Err(failure),
    };
  }

  /// Protects the view or replaces its PIN. Either every write commits or none
  /// does, so a refusal keeps the old verifier, counter and protection.
  Future<Result<void, SecretFailure>> replaceCredential(
    String? next,
    String view,
  ) async {
    SecretFailure? refused;
    final result = await boundary(
      () => inventoryWriteTransaction(_database, () async {
        refused = await _replace(next, view);
      }),
      orElse: StoreSecretFailure.new,
    );
    final refusal = refused;
    return refusal == null ? result : Err(refusal);
  }

  Future<SecretFailure?> _replace(String? next, String viewId) async {
    final state = await _stateForUpdate();
    final view = await _view(viewId);
    final existing = await _credentialOf(view);
    var credentialId = view.credentialId;
    if (next != null) {
      // D66 gates protection, not a change of PIN: a view that already has a
      // verifier (a migrated one never proved its seeds) rotates it without
      // adding a secret. Only no PIN -> PIN is judged.
      if (existing == null) {
        final refusal = await _guard.require(
          await viewSecrets(_database, view.id),
        );
        if (refusal != null) return refusal;
        credentialId = _newCredentialId();
      }
      final target = credentialId;
      if (target == null) throw const _InvalidAccessState();
      final salt = AccessVerifier.newSalt();
      final verifier = await AccessVerifier.derive(next, salt);
      if (existing == null) {
        // A first PIN is the view's own: a new row, never an id another view
        // may already use.
        await _database
            .into(_database.credentials)
            .insert(
              CredentialsCompanion.insert(
                id: target,
                scheme: AccessVerifier.scheme,
                salt: salt,
                params: AccessVerifier.params,
                verifier: verifier,
              ),
            );
      } else {
        // A rotation rewrites the row the view uses: every view that shares
        // it follows, which the caller announces.
        await (_database.update(
          _database.credentials,
        )..where((row) => row.id.equals(existing.id))).write(
          CredentialsCompanion(
            scheme: Value(AccessVerifier.scheme),
            salt: Value(salt),
            params: Value(AccessVerifier.params),
            verifier: Value(verifier),
          ),
        );
      }
    }
    final viewUpdate = _database.update(_database.views)
      ..where((v) => v.id.equals(view.id));
    await viewUpdate.write(
      ViewsCompanion(credentialId: Value(next == null ? null : credentialId)),
    );
    if (existing != null && next == null) {
      await _deleteCredentialIfUnused(existing.id);
    }
    // The counter belongs to the credentials. Another protected view's guesses
    // are not this session's to forget: a session opened on a view with no PIN
    // that sets one must not return that counter to zero.
    final others = await _protectedViewsOtherThan(view.id);
    if (others == 0) {
      final reset = state.copyWith(
        failedAttempts: 0,
        lockedUntil: const Value(null),
      );
      await _database.update(_database.accessState).replace(reset);
      _remaining(reset);
    }
    return null;
  }

  /// Gives [viewId] a credential of its own, with the same PIN, so a later
  /// rotation of either no longer moves the other.
  Future<Result<void, SecretFailure>> dissociate(String viewId) => boundary(
    () => inventoryWriteTransaction(_database, () async {
      await serializeInventoryWrites(_database);
      final view = await _view(viewId);
      final shared = await _credentialOf(view);
      if (shared == null) return;
      final users = await (_database.select(
        _database.views,
      )..where((v) => v.credentialId.equals(shared.id))).get();
      if (users.length < 2) return;
      final own = _newCredentialId();
      await _database
          .into(_database.credentials)
          .insert(
            CredentialsCompanion.insert(
              id: own,
              scheme: shared.scheme,
              salt: shared.salt,
              params: shared.params,
              verifier: shared.verifier,
            ),
          );
      await (_database.update(_database.views)
            ..where((v) => v.id.equals(view.id)))
          .write(ViewsCompanion(credentialId: Value(own)));
    }),
    orElse: StoreSecretFailure.new,
  );

  static String _newCredentialId() {
    final random = math.Random.secure();
    return 'credential-${[for (var i = 0; i < 8; i++) random.nextInt(256).toRadixString(16).padLeft(2, '0')].join()}';
  }

  Future<void> _deleteCredentialIfUnused(String id) async {
    final remaining = await (_database.select(
      _database.views,
    )..where((v) => v.credentialId.equals(id))).get();
    if (remaining.isEmpty) {
      await (_database.delete(
        _database.credentials,
      )..where((c) => c.id.equals(id))).go();
    }
  }

  Future<int> _protectedViewsOtherThan(String id) async =>
      (await (_database.select(_database.views)..where(
                (v) => v.id.equals(id).not() & v.credentialId.isNotNull(),
              ))
              .get())
          .length;

  Future<List<AccessViewRow>> _views() async {
    final views =
        await (_database.select(_database.views)..orderBy([
              (v) => OrderingTerm.asc(v.name),
              (v) => OrderingTerm.asc(v.id),
            ]))
            .get();
    if (views.isEmpty) throw const _InvalidAccessState();
    return views;
  }

  List<ViewSummary> _summaries(List<AccessViewRow> views) => List.unmodifiable([
    for (final view in views)
      ViewSummary(
        id: ViewId(view.id),
        name: view.name,
        isProtected: view.credentialId != null,
        backgroundEnabled: view.backgroundEnabled,
      ),
  ]);

  Future<AccessStateRow> _state() async {
    final state = await _database
        .select(_database.accessState)
        .getSingleOrNull();
    if (state == null) throw const _InvalidAccessState();
    return state;
  }

  Future<AccessStateRow> _stateForUpdate() async {
    await serializeInventoryWrites(_database);
    return _state();
  }

  Future<AccessViewRow> _view(String id) async {
    final view = await (_database.select(
      _database.views,
    )..where((v) => v.id.equals(id))).getSingleOrNull();
    if (view == null) throw const _InvalidAccessState();
    return view;
  }

  Future<bool> _anyCredential() async {
    final views = await _database.select(_database.views).get();
    if (views.isEmpty) throw const _InvalidAccessState();
    for (final view in views) {
      if (await _credentialOf(view) != null) return true;
    }
    return false;
  }

  /// The credential protecting [view], or null when it has none. A reference
  /// to a missing or unsupported credential is an invalid state, never an
  /// unprotected view.
  Future<Credential?> _credentialOf(AccessViewRow view) async {
    final id = view.credentialId;
    return id == null ? null : _credentialRow(id);
  }

  Future<Credential> _credentialRow(String id) async {
    final credential = await (_database.select(
      _database.credentials,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    if (credential == null ||
        !AccessVerifier.supports(
          storedScheme: credential.scheme,
          storedParams: credential.params,
          salt: credential.salt,
          verifier: credential.verifier,
        )) {
      throw const _InvalidAccessState();
    }
    return credential;
  }

  AccessAttempt _attempt(AccessStateRow state, {required bool accepted}) {
    final epoch = state.lockedUntil;
    return AccessAttempt(
      accepted: accepted,
      failedAttempts: state.failedAttempts,
      lockedUntil: epoch == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(epoch),
      remaining: _remaining(state),
    );
  }

  Duration _remaining(AccessStateRow state) {
    final snapshot = (attempts: state.failedAttempts, until: state.lockedUntil);
    if (snapshot != _cooldownState) {
      _cooldownState = snapshot;
      _cooldown
        ..reset()
        ..start();
    }
    // A new process or a write from another connection has no trusted elapsed
    // time for this state. Apply its full delay from the first observation.
    final monotonic =
        _cooldownMilliseconds(snapshot.attempts) -
        _cooldown.elapsedMilliseconds;
    final now = DateTime.now().millisecondsSinceEpoch;
    final wall = (snapshot.until ?? now) - now;
    return Duration(
      milliseconds: math.max(wall, monotonic).clamp(0, _maxEpoch),
    );
  }

  static int _cooldownMilliseconds(int attempts) =>
      (attempts - 3).clamp(0, _maxEpoch ~/ _attemptIncrementMs) *
      _attemptIncrementMs;
}

final class _InvalidAccessState implements Exception {
  const _InvalidAccessState();
}
