import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/exchange_api_key.dart';
import '../domain/exchange_access.dart';
import '../domain/exchange_failure.dart';
import 'exchange_credentials.dart';

/// Foreground session authority. Platform storage and WebView cleanup are
/// supplied during setup; their ordering and the journal belong here.
abstract interface class ExchangeAccessLifecycle {
  factory ExchangeAccessLifecycle.open({
    required ExchangeCredentials apiKeyRepository,
    required Future<bool> Function() readEnvironment,
    required Future<bool> Function() platformAllowed,
    required Future<void> Function() disconnectNotifications,
    required Future<void> Function() clearCookies,
    required Future<Object?> Function() readPreference,
    required Future<bool> Function(String) writePreference,
  }) = _ExchangeAccessLifecycle;

  static const preferenceKey = 'exchange_access';

  ExchangeAccess get current;
  int get epoch;
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
  }) : _keys = apiKeyRepository;

  final ExchangeCredentials _keys;
  final Future<bool> Function() _readEnvironment;
  final Future<bool> Function() _platformAllowed;
  final Future<void> Function() _disconnectNotifications;
  final Future<void> Function() _clearCookies;
  final Future<Object?> Function() _readPreference;
  final Future<bool> Function(String) _writePreference;
  final _changes = StreamController<ExchangeAccess>.broadcast(sync: true);
  Future<void> _queue = Future.value();
  ExchangeAccess _current = const ExchangeAccessResolving();
  int _epoch = 0;
  bool _cleanupPending = false;

  @override
  ExchangeAccess get current => _current;
  @override
  int get epoch => _epoch;

  void _emit(ExchangeAccess value) {
    _current = value;
    _changes.add(value);
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

  @override
  Future<Result<void, ExchangeFailure>> resolve() {
    final token = ++_epoch;
    final disconnected = _attempt(_disconnectNotifications);
    return _serial(() async {
      await disconnected;
      try {
        if (_cleanupPending) {
          return await _signOutCleanup();
        }
        final preference = await _read();
        if (token != _epoch) {
          return const Ok(null);
        }
        if (preference.pending) {
          return await _signOutCleanup();
        }
        final isTestnet = await _readEnvironment();
        final key = await _keys.readActiveApiKey(isTestnet: isTestnet);
        if (token != _epoch) {
          return const Ok(null);
        }
        if (key case Err()) {
          _emit(
            preference.enabled == false
                ? const ExchangeAccessDisabled()
                : const ExchangeAccessEnabled(ExchangeAccessSession.unreadable),
          );
          return const Err(ExchangeApiKeyStorageFailure());
        }
        final present = (key as Ok<String?, dynamic>).value != null;
        final enabled = preference.enabled ?? present;
        if (preference.enabled == null && present) {
          final saved = await _write(true, false);
          if (token != _epoch) {
            return const Ok(null);
          }
          if (!saved) {
            _emit(const ExchangeAccessUnreadable());
            return const Err(ExchangeUnexpectedFailure());
          }
        }
        if (token != _epoch) {
          return const Ok(null);
        }
        _emit(
          enabled
              ? ExchangeAccessEnabled(
                  present
                      ? ExchangeAccessSession.signedIn
                      : ExchangeAccessSession.signedOut,
                )
              : const ExchangeAccessDisabled(),
        );
        return const Ok(null);
      } on Exception catch (_) {
        if (token == _epoch) {
          _emit(const ExchangeAccessUnreadable());
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
    final token = onlyIfUnset ? _epoch : ++_epoch;
    return _serial(() async {
      if (token != _epoch || _cleanupPending) {
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
          return const Err(ExchangeUnexpectedFailure());
        }
        final environment = await _readEnvironment();
        final key = await _keys.readActiveApiKey(isTestnet: environment);
        if (key case Err()) {
          return const Err(ExchangeApiKeyStorageFailure());
        }
        final present = (key as Ok<String?, dynamic>).value != null;
        final enabled = choice || present;
        if (token != _epoch || _cleanupPending) {
          return const Err(ExchangeUnexpectedFailure());
        }
        if (!await _write(enabled, false)) {
          return const Err(ExchangeUnexpectedFailure());
        }
        if (token != _epoch) {
          return const Err(ExchangeUnexpectedFailure());
        }
        _emit(
          enabled
              ? ExchangeAccessEnabled(
                  present
                      ? ExchangeAccessSession.signedIn
                      : ExchangeAccessSession.signedOut,
                )
              : const ExchangeAccessDisabled(),
        );
        return const Ok(null);
      } on Exception catch (_) {
        if (token == _epoch) {
          _emit(const ExchangeAccessUnreadable());
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
    _emit(const ExchangeAccessSignOutIncomplete());
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
      return const Err(ExchangeSessionClearFailure());
    }
    _cleanupPending = false;
    _emit(const ExchangeAccessDisabled());
    return const Ok(null);
  }

  @override
  Future<Result<void, ExchangeFailure>> signOut() {
    ++_epoch;
    _cleanupPending = true;
    _emit(const ExchangeAccessSignOutIncomplete());
    // Journal before queued work finishes, so a killed app still completes the
    // sign-out at the next start. The cleanup writes the journal again.
    final journaled = _write(false, true);
    final disconnected = _attempt(_disconnectNotifications);
    return _serial(() async {
      await journaled;
      await disconnected;
      return _signOutCleanup();
    });
  }

  @override
  Future<Result<void, ExchangeFailure>> runAuthenticated(
    Future<Result<void, ExchangeFailure>> Function() operation,
  ) {
    final token = _epoch;
    return _serial(() async {
      if (token != _epoch) {
        return const Err(ExchangeOperationStaleFailure());
      }
      if (_current case ExchangeAccessEnabled(
        session: ExchangeAccessSession.signedIn,
      )) {
        final result = await operation();
        if (token != _epoch) {
          await _attempt(_disconnectNotifications);
          return const Err(ExchangeOperationStaleFailure());
        }
        return result;
      }
      return const Err(ExchangeNotAuthenticatedFailure());
    });
  }

  @override
  Future<Result<void, ExchangeFailure>> expireSession({
    required int epoch,
    required bool isTestnet,
  }) {
    if (epoch != _epoch) {
      return Future.value(const Ok(null));
    }
    return _serial(() async {
      if (epoch != _epoch || _current is! ExchangeAccessEnabled) {
        return const Ok(null);
      }
      try {
        final environment = await _readEnvironment();
        if (epoch != _epoch || environment != isTestnet) {
          return const Ok(null);
        }
        final cleanupEpoch = ++_epoch;
        _emit(const ExchangeAccessEnabled(ExchangeAccessSession.unreadable));
        final disconnected = await _attempt(_disconnectNotifications);
        if (cleanupEpoch != _epoch) return const Ok(null);
        final saved = await _write(true, false);
        if (cleanupEpoch != _epoch) {
          return const Ok(null);
        }
        if (!saved) {
          return const Err(ExchangeUnexpectedFailure());
        }
        var removed = false;
        try {
          final deleted = await _keys.deleteApiKey(isTestnet: isTestnet);
          removed = deleted is Ok;
        } on Exception catch (_) {}
        final cookies = await _attempt(_clearCookies);
        if (!disconnected || !removed || !cookies) {
          return const Err(ExchangeSessionClearFailure());
        }
        if (cleanupEpoch == _epoch) {
          _emit(const ExchangeAccessEnabled(ExchangeAccessSession.signedOut));
        }
        return const Ok(null);
      } on Exception catch (_) {
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
    if (!isCurrent() || _current is! ExchangeAccessEnabled) {
      return const Err(ExchangeAuthenticationFailure());
    }
    final token = ++_epoch;
    try {
      if (token != _epoch || !isCurrent()) {
        return const Err(ExchangeAuthenticationFailure());
      }
    } on Exception {
      return const Err(ExchangeAuthenticationFailure());
    }
    final generated = await generateApiKey();
    if (generated case Err(:final failure)) {
      return Err(failure);
    }
    return _serial(() async {
      if (token != _epoch ||
          !isCurrent() ||
          _current is! ExchangeAccessEnabled ||
          await _readEnvironment() != isTestnet ||
          token != _epoch ||
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
      if (token != _epoch) {
        return const Err(ExchangeOperationStaleFailure());
      }
      _emit(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));
      return const Ok(null);
    });
  }
}
