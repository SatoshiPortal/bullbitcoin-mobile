import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/exchange_api_key.dart';
import '../domain/exchange_access.dart';
import '../domain/exchange_availability.dart';
import '../domain/exchange_environment.dart';
import '../domain/exchange_failure.dart';
import '../session/exchange_access_event.dart';
import 'exchange_credentials.dart';

/// Foreground session authority. Platform storage and WebView cleanup are
/// supplied during setup; their ordering and the journal belong here.
///
/// Every state change goes through [ExchangeAccess.next]. A session starts only
/// when a key is stored or found for an environment without a current
/// session, so a failed sign-in or a repeated read ends nothing. The
/// notification socket is an effect of [ExchangeAccessSignedIn]: it is
/// opened on entering it and closed on leaving it.
abstract interface class ExchangeAccessLifecycle {
  factory ExchangeAccessLifecycle.open({
    required ExchangeCredentials apiKeyRepository,
    required Future<bool> Function() readEnvironment,
    required Future<bool> Function() platformAllowed,
    required Future<void> Function() disconnectNotifications,
    required Future<void> Function() clearCookies,
    required Future<Object?> Function() readPreference,
    required Future<bool> Function(String) writePreference,
    Future<void> Function(ExchangeEnvironment, {required bool reconnect})?
    connectNotifications,
    String Function()? newSessionId,
  }) = _ExchangeAccessLifecycle;

  static const preferenceKey = 'exchange_access';

  ExchangeAccess get current;

  /// The current session, only while signed in.
  ExchangeSession? get session;
  Stream<ExchangeAccess> watch();
  @useResult
  Future<Result<void, ExchangeFailure>> resolve();
  @useResult
  Future<Result<void, ExchangeFailure>> enable({
    bool onlyIfUnset = false,
    bool choice = true,
    bool forSupport = false,
  });
  @useResult
  Future<Result<void, ExchangeFailure>> signOut();
  @useResult
  Future<Result<void, ExchangeFailure>> runAuthenticated(
    Future<Result<void, ExchangeFailure>> Function() operation,
  );

  /// Decides whether a trading route may open now. A signed-in session waits
  /// for queued reconciliation before it is trusted.
  @useResult
  Future<Result<ExchangeAvailability, ExchangeFailure>> tradingAvailability();

  /// Expires the session with [epoch] when its key was rejected. Any other
  /// session, or none, is left alone.
  @useResult
  Future<Result<void, ExchangeFailure>> expireSession({
    required int epoch,
    required bool isTestnet,
  });
  @useResult
  Future<Result<void, ExchangeFailure>> completeAuthentication({
    required Future<Result<ExchangeApiKey, ExchangeFailure>> Function()
    generateApiKey,
    required bool isTestnet,
    required bool Function() isCurrent,
  });

  /// Reopens the socket of the current session (the platform may have
  /// dropped it while the app was hidden). Nothing while signed out.
  Future<void> reconnectNotifications();
}

final class _ExchangeAccessLifecycle implements ExchangeAccessLifecycle {
  _ExchangeAccessLifecycle({
    required ExchangeCredentials apiKeyRepository,
    required this._readEnvironment,
    required this._platformAllowed,
    required this._disconnectNotifications,
    required this._clearCookies,
    required this._readPreference,
    required this._writePreference,
    Future<void> Function(ExchangeEnvironment, {required bool reconnect})?
    connectNotifications,
    String Function()? newSessionId,
  }) : _keys = apiKeyRepository,
       _connectNotifications = connectNotifications ?? _noSocket,
       _newSessionId = newSessionId ?? _randomSessionId;

  final ExchangeCredentials _keys;
  final Future<bool> Function() _readEnvironment;
  final Future<bool> Function() _platformAllowed;
  final Future<void> Function() _disconnectNotifications;
  final Future<void> Function(ExchangeEnvironment, {required bool reconnect})
  _connectNotifications;
  final Future<void> Function() _clearCookies;
  final Future<Object?> Function() _readPreference;
  final Future<bool> Function(String) _writePreference;
  final String Function() _newSessionId;
  final _changes = StreamController<ExchangeAccess>.broadcast(sync: true);
  Future<void> _queue = Future.value();
  ExchangeAccess _current = const ExchangeAccessResolving();

  /// The epoch of the newest session of this run.
  int _sessions = 0;

  /// Lets a newer resolve, enable or sign-out supersede a queued older one.
  /// Never seen outside: sessions carry their own epoch.
  int _generation = 0;
  bool _cleanupPending = false;

  static Future<void> _noSocket(
    ExchangeEnvironment _, {
    required bool reconnect,
  }) async {}

  static String _randomSessionId() {
    final random = Random.secure();
    return [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }

  @override
  ExchangeAccess get current => _current;

  @override
  ExchangeSession? get session => _current.signedInSession;

  /// The session a key found or stored now would start. Its epoch is taken
  /// only if the transition starts it.
  ExchangeSession _candidate(ExchangeEnvironment environment) =>
      ExchangeSession(
        environment: environment,
        epoch: _sessions + 1,
        sessionId: _newSessionId(),
      );

  void _apply(ExchangeAccessEvent event) {
    final previous = _current;
    final next = previous.next(event);
    if (next == previous) return;
    final started = switch (next) {
      ExchangeAccessSignedIn(:final session) ||
      ExchangeAccessExpiring(:final session) => session.epoch,
      ExchangeAccessResolving() ||
      ExchangeAccessUnreadable() ||
      ExchangeAccessDisabled() ||
      ExchangeAccessSignOutIncomplete() ||
      ExchangeAccessSignedOut() ||
      ExchangeAccessCredentialUnreadable() => 0,
    };
    if (started > _sessions) _sessions = started;
    _current = next;
    _changes.add(next);
    final before = previous.signedInSession;
    final after = next.signedInSession;
    if (before == after) return;
    if (before != null) unawaited(_attempt(_disconnectNotifications));
    if (after != null) {
      unawaited(
        _attempt(
          () => _connectNotifications(after.environment, reconnect: false),
        ),
      );
    }
  }

  @override
  Stream<ExchangeAccess> watch() => Stream.multi((controller) {
    final subscription = _changes.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.add(_current);
    controller.onCancel = subscription.cancel;
  });

  Future<T> _serial<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  Future<({bool? enabled, bool pending})> _read() async {
    final raw = await _readPreference();
    if (raw == null) {
      return (enabled: null, pending: false);
    }
    if (raw is! String) {
      throw const FormatException();
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> ||
        (decoded['enabled'] != null && decoded['enabled'] is! bool) ||
        decoded['signOutPending'] is! bool ||
        !decoded.containsKey('enabled')) {
      throw const FormatException();
    }
    return (
      enabled: decoded['enabled'] as bool?,
      pending: decoded['signOutPending'] as bool,
    );
  }

  Future<bool> _write(bool? enabled, bool pending) async {
    try {
      final encoded = jsonEncode({
        'enabled': enabled,
        'signOutPending': pending,
      });
      return await _writePreference(encoded);
    } on Exception catch (_) {
      return false;
    }
  }

  static ExchangeEnvironment _environment(bool isTestnet) =>
      isTestnet ? ExchangeEnvironment.testnet : ExchangeEnvironment.mainnet;

  @override
  Future<Result<void, ExchangeFailure>> resolve() {
    final token = ++_generation;
    return _serial(() async {
      try {
        if (_cleanupPending) {
          return await _signOutCleanup();
        }
        final preference = await _read();
        if (token != _generation) {
          return const Ok(null);
        }
        if (preference.pending) {
          return await _signOutCleanup();
        }
        final environment = _environment(await _readEnvironment());
        final key = await _keys.readActiveApiKey(
          isTestnet: environment == ExchangeEnvironment.testnet,
        );
        if (token != _generation) {
          return const Ok(null);
        }
        if (key case Err()) {
          _apply(
            preference.enabled == false
                ? const AccessFoundDisabled()
                : AccessKeyUnreadable(environment),
          );
          return const Err(ExchangeApiKeyStorageFailure());
        }
        final present = (key as Ok<String?, dynamic>).value != null;
        final enabled = preference.enabled ?? present;
        if (preference.enabled == null && present) {
          final saved = await _write(true, false);
          if (token != _generation) {
            return const Ok(null);
          }
          if (!saved) {
            _apply(const AccessChoiceUnreadable());
            return const Err(ExchangeUnexpectedFailure());
          }
        }
        if (token != _generation) {
          return const Ok(null);
        }
        _apply(
          !enabled
              ? const AccessFoundDisabled()
              : present
              ? AccessFoundKey(_candidate(environment))
              : AccessFoundSignedOut(environment),
        );
        return const Ok(null);
      } on Exception catch (_) {
        if (token == _generation) {
          _apply(const AccessChoiceUnreadable());
        }
        return const Err(ExchangeUnexpectedFailure());
      }
    });
  }

  @override
  Future<Result<void, ExchangeFailure>> enable({
    bool onlyIfUnset = false,
    bool choice = true,
    bool forSupport = false,
  }) {
    final token = onlyIfUnset ? _generation : ++_generation;
    return _serial(() async {
      if (token != _generation || _cleanupPending) {
        return const Err(ExchangeSessionClearFailure());
      }
      try {
        final preference = await _read();
        if (preference.pending) {
          return const Err(ExchangeSessionClearFailure());
        }
        if (onlyIfUnset && preference.enabled != null) {
          return const Ok(null);
        }
        if (choice && !forSupport && !await _platformAllowed()) {
          return const Err(ExchangePlatformNotAllowedFailure());
        }
        final environment = _environment(await _readEnvironment());
        final key = await _keys.readActiveApiKey(
          isTestnet: environment == ExchangeEnvironment.testnet,
        );
        if (key case Err()) {
          return const Err(ExchangeApiKeyStorageFailure());
        }
        final present = (key as Ok<String?, dynamic>).value != null;
        final enabled = choice || present;
        if (token != _generation || _cleanupPending) {
          return const Err(ExchangeUnexpectedFailure());
        }
        if (!await _write(enabled, false)) {
          return const Err(ExchangeUnexpectedFailure());
        }
        if (token != _generation) {
          return const Err(ExchangeUnexpectedFailure());
        }
        _apply(
          !enabled
              ? const AccessFoundDisabled()
              : present
              ? AccessFoundKey(_candidate(environment))
              : AccessFoundSignedOut(environment),
        );
        return const Ok(null);
      } on Exception catch (_) {
        if (token == _generation) {
          _apply(const AccessChoiceUnreadable());
        }
        return const Err(ExchangeUnexpectedFailure());
      }
    });
  }

  Future<bool> _attempt(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } on Exception catch (_) {
      return false;
    }
  }

  Future<Result<void, ExchangeFailure>> _signOutCleanup() async {
    _cleanupPending = true;
    _apply(const AccessFoundSignOutPending());
    final journaled = await _write(false, true);
    final disconnected = await _attempt(_disconnectNotifications);
    var mainCleared = false;
    var testCleared = false;
    try {
      final deleted = await _keys.deleteApiKey(isTestnet: false);
      mainCleared = deleted is Ok;
    } on Exception catch (_) {}
    try {
      final deleted = await _keys.deleteApiKey(isTestnet: true);
      testCleared = deleted is Ok;
    } on Exception catch (_) {}
    final cookiesCleared = await _attempt(_clearCookies);
    if (!journaled ||
        !disconnected ||
        !mainCleared ||
        !testCleared ||
        !cookiesCleared ||
        !await _write(false, false)) {
      _apply(const AccessSignOutFailed());
      return const Err(ExchangeSessionClearFailure());
    }
    _cleanupPending = false;
    _apply(const AccessSignOutCompleted());
    return const Ok(null);
  }

  @override
  Future<Result<void, ExchangeFailure>> signOut() {
    ++_generation;
    _cleanupPending = true;
    _apply(const AccessSignOutStarted());
    // Journal before queued work finishes, so a killed app still completes the
    // sign-out at the next start. The cleanup writes the journal again.
    final journaled = _write(false, true);
    return _serial(() async {
      await journaled;
      return _signOutCleanup();
    });
  }

  @override
  Future<Result<void, ExchangeFailure>> runAuthenticated(
    Future<Result<void, ExchangeFailure>> Function() operation,
  ) {
    // Queued behind any resolve or sign-out already asked for, so the
    // session it sees is the settled one.
    return _serial(() async {
      final session = _current.signedInSession;
      if (session == null) {
        return const Err(ExchangeNotAuthenticatedFailure());
      }
      final result = await operation();
      if (_current.signedInSession != session) {
        return const Err(ExchangeOperationStaleFailure());
      }
      return result;
    });
  }

  @override
  Future<Result<ExchangeAvailability, ExchangeFailure>>
  tradingAvailability() async {
    try {
      final availability = ExchangeAvailability.resolve(
        platformAllowed: await _platformAllowed(),
        access: _current,
      );
      if (availability == ExchangeAvailability.ready) {
        // Reconciliation uses the same queue. A displayed session is not
        // permission to trade before the active environment has been read.
        final settled = await runAuthenticated(() async => const Ok(null));
        if (settled case Err(:final failure)) {
          if (failure is! ExchangeNotAuthenticatedFailure) return Err(failure);
        }
      }
      return Ok(
        ExchangeAvailability.resolve(
          platformAllowed: await _platformAllowed(),
          access: _current,
        ),
      );
    } on Exception {
      return const Err(ExchangeAccountUnavailableFailure());
    }
  }

  @override
  Future<Result<void, ExchangeFailure>> expireSession({
    required int epoch,
    required bool isTestnet,
  }) {
    if (_current.signedInSession?.epoch != epoch) {
      return Future.value(const Ok(null));
    }
    return _serial(() async {
      final session = _current.signedInSession;
      if (session == null ||
          session.epoch != epoch ||
          session.environment != _environment(isTestnet)) {
        return const Ok(null);
      }
      try {
        final environment = await _readEnvironment();
        if (_current.signedInSession != session || environment != isTestnet) {
          return const Ok(null);
        }
        ++_generation;
        _apply(AccessSessionRejected(epoch));
        final saved = await _write(true, false);
        // A sign-out started meanwhile owns the credentials now.
        if (_current != ExchangeAccessExpiring(session)) {
          return const Ok(null);
        }
        if (!saved) {
          _apply(AccessExpiryFailed(epoch));
          return const Err(ExchangeUnexpectedFailure());
        }
        var removed = false;
        try {
          final deleted = await _keys.deleteApiKey(isTestnet: isTestnet);
          removed = deleted is Ok;
        } on Exception catch (_) {}
        final cookies = await _attempt(_clearCookies);
        if (!removed || !cookies) {
          _apply(AccessExpiryFailed(epoch));
          return const Err(ExchangeSessionClearFailure());
        }
        _apply(AccessExpiryCompleted(epoch));
        return const Ok(null);
      } on Exception catch (_) {
        _apply(AccessExpiryFailed(epoch));
        return const Err(ExchangeSessionClearFailure());
      }
    });
  }

  @override
  Future<Result<void, ExchangeFailure>> completeAuthentication({
    required Future<Result<ExchangeApiKey, ExchangeFailure>> Function()
    generateApiKey,
    required bool isTestnet,
    required bool Function() isCurrent,
  }) async {
    try {
      if (!isCurrent() || !accessAcceptsKey(_current)) {
        return const Err(ExchangeAuthenticationFailure());
      }
    } on Exception {
      return const Err(ExchangeAuthenticationFailure());
    }
    // Nothing changes before the key exists: a failed generation ends no
    // session and cancels no work.
    final generated = await generateApiKey();
    if (generated case Err(:final failure)) {
      return Err(failure);
    }
    return _serial(() async {
      if (!isCurrent() ||
          !accessAcceptsKey(_current) ||
          await _readEnvironment() != isTestnet ||
          !isCurrent()) {
        return const Err(ExchangeAuthenticationFailure());
      }
      final result = await _keys.saveApiKey(
        (generated as Ok).value,
        isTestnet: isTestnet,
      );
      if (result case Err()) {
        return const Err(ExchangeApiKeyStorageFailure());
      }
      // A committed native write cannot be undone by merely closing its view.
      // Explicit sign-out is queued behind this write and owns credential deletion.
      if (!accessAcceptsKey(_current)) {
        return const Err(ExchangeOperationStaleFailure());
      }
      _apply(AccessKeyStored(_candidate(_environment(isTestnet))));
      return const Ok(null);
    });
  }

  @override
  Future<void> reconnectNotifications() async {
    final session = _current.signedInSession;
    if (session == null) return;
    await _attempt(
      () => _connectNotifications(session.environment, reconnect: true),
    );
  }
}
