import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:drift/drift.dart';
import 'package:primitives/primitives.dart';

import '../crypto/access_verifier.dart';
import '../domain/access_attempt.dart';
import '../domain/domain.dart';
import '../domain/inventory_backup_verification.dart';
import 'boundary.dart';
import 'inventory_import.dart';
import 'secrets_database.dart';
import 'secrets_database.drift.dart';

/// Single-view access authority. Comparison and rate limiting commit together.
final class AccessRepository {
  static const _maxEpoch = 8640000000000000;
  static const _attemptIncrementMs = 30000;

  final SecretsDatabase _database;
  final Stopwatch _cooldown = Stopwatch();
  ({int attempts, int? until})? _cooldownState;

  @internal
  AccessRepository(this._database);

  Future<Result<bool, SecretFailure>> isProtected() => boundary(
    () async => (await _credential()) != null,
    orElse: FetchSecretFailure.new,
  );

  Future<Result<AccessAttempt, SecretFailure>> status() => boundary(() async {
    final state = await _state();
    return _attempt(state, accepted: false);
  }, orElse: FetchSecretFailure.new);

  Future<Result<AccessAttempt, SecretFailure>> unlock(String candidate) =>
      boundary(
        () => _database.transaction(() async {
          // Take the write lock before reading. Two SQLite connections must
          // never evaluate a guess against the same attempt count.
          final state = await _stateForUpdate();
          final blocked = _attempt(state, accepted: false);
          if (blocked.remaining > Duration.zero) return blocked;
          final credential = await _credential();
          if (credential == null) return _attempt(state, accepted: true);

          final output = await AccessVerifier.derive(
            candidate,
            credential.salt,
          );
          final accepted = AccessVerifier.equals(output, credential.verifier);
          output.fillRange(0, output.length, 0);
          final attempts = accepted
              ? 0
              : state.failedAttempts.clamp(0, _maxEpoch) + 1;
          final cooldown = _cooldownMilliseconds(attempts);
          final until = cooldown == 0
              ? null
              : (DateTime.now().millisecondsSinceEpoch + cooldown).clamp(
                  -_maxEpoch,
                  _maxEpoch,
                );
          final next = state.copyWith(
            failedAttempts: attempts,
            lockedUntil: Value(until),
          );
          await _database.update(_database.accessState).replace(next);
          return _attempt(next, accepted: accepted);
        }),
        orElse: FetchSecretFailure.new,
      );

  Future<Result<void, SecretFailure>> setBackgroundEnabled(bool enabled) =>
      boundary(
        () => _database.transaction(() async {
          final view = await _defaultView();
          await (_database.update(_database.views)
                ..where((v) => v.id.equals(view.id)))
              .write(ViewsCompanion(backgroundEnabled: Value(enabled)));
        }),
        orElse: StoreSecretFailure.new,
      );

  Future<Result<bool, SecretFailure>> hasVerifiedBackups(
    InventoryBackupVerification verification,
  ) async {
    final view = await boundary(_defaultView, orElse: FetchSecretFailure.new);
    return switch (view) {
      Ok(:final value) => _checkBackups(value, verification),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<void, SecretFailure>> replaceCredential(
    String? next, {
    InventoryBackupVerification? backupVerification,
  }) => boundary(
    () => _database.transaction(() async {
      final state = await _stateForUpdate();
      final view = await _defaultView();
      final existing = await _credential();
      if (next != null) {
        if (backupVerification == null) throw const _InvalidAccessState();
        final backup = await _checkBackups(view, backupVerification);
        if (backup is! Ok<bool, SecretFailure> || !backup.value) {
          throw const _ValidBackupRequired();
        }
        final salt = AccessVerifier.newSalt();
        await _database
            .into(_database.credentials)
            .insertOnConflictUpdate(
              CredentialsCompanion.insert(
                id: initialCredentialId,
                scheme: AccessVerifier.scheme,
                salt: salt,
                params: AccessVerifier.params,
                verifier: await AccessVerifier.derive(next, salt),
              ),
            );
      }
      final viewUpdate = _database.update(_database.views)
        ..where((v) => v.id.equals(view.id));
      await viewUpdate.write(
        ViewsCompanion(
          credentialId: Value(next == null ? null : initialCredentialId),
        ),
      );
      if (existing != null && next == null) {
        await (_database.delete(
          _database.credentials,
        )..where((c) => c.id.equals(existing.id))).go();
      }
      final reset = state.copyWith(
        failedAttempts: 0,
        lockedUntil: const Value(null),
      );
      await _database.update(_database.accessState).replace(reset);
      _remaining(reset);
    }),
    orElse: StoreSecretFailure.new,
  );

  Future<Result<bool, SecretFailure>> _checkBackups(
    AccessViewRow view,
    InventoryBackupVerification verification,
  ) async {
    final parents = await boundary(() async {
      const prefix = 'secret:';
      final members = await (_database.select(
        _database.viewMembers,
      )..where((member) => member.viewId.equals(view.id))).get();
      return Set<String>.unmodifiable({
        for (final member in members)
          if (member.member.startsWith(prefix))
            member.member.substring(prefix.length),
      });
    }, orElse: FetchSecretFailure.new);
    return switch (parents) {
      Ok(value: final ids) when ids.isEmpty => const Ok(true),
      Ok(:final value) => verification.hasVerifiedBackups(value),
      Err(:final failure) => Err(failure),
    };
  }

  Future<AccessStateRow> _state() async {
    final state = await _database
        .select(_database.accessState)
        .getSingleOrNull();
    if (state == null) throw const _InvalidAccessState();
    return state;
  }

  Future<AccessStateRow> _stateForUpdate() async {
    await _database.customStatement(
      'UPDATE access_state SET singleton = singleton WHERE singleton = 1',
    );
    return _state();
  }

  Future<AccessViewRow> _defaultView() async {
    final view = await (_database.select(
      _database.views,
    )..where((v) => v.id.equals(defaultViewId))).getSingleOrNull();
    if (view == null) throw const _InvalidAccessState();
    return view;
  }

  Future<Credential?> _credential() async {
    final id = (await _defaultView()).credentialId;
    if (id == null) return null;
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

final class _ValidBackupRequired implements Exception {
  const _ValidBackupRequired();
}
