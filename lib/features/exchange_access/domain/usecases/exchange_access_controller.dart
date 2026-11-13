import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange_access/domain/exchange_access.dart';
import 'package:bb_mobile/features/exchange_access/domain/exchange_access_failure.dart';
import 'package:bb_mobile/features/exchange_access/domain/repositories/exchange_access_repository.dart';

/// Owns the installation-local choice. Session facts never contain credentials.
class ExchangeAccessController {
  ExchangeAccessController({required this._repository});

  final ExchangeAccessRepository _repository;
  final _changes = StreamController<ExchangeAccess>.broadcast(sync: true);
  Future<void> _queue = Future.value();
  Map<bool, ExchangeAccess> _values = {};
  ExchangeAccess _current = const ExchangeAccess();
  bool? _environment;
  int _generation = 0;

  ExchangeAccess get current => _current;
  int get generation => _generation;

  /// Close authenticated capabilities before resolving an environment change.
  void suspend() {
    _generation++;
    _emit(_current.copyWith(session: ExchangeSessionFact.resolving));
  }

  Future<void> settle() => _queue;

  bool? get isTestnet => _environment;
  Stream<ExchangeAccess> watch() => Stream.multi((controller) {
    final subscription = _changes.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.add(_current);
    controller.onCancel = subscription.cancel;
  });

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        result.complete(await operation());
      } on Exception catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  void _emit(ExchangeAccess value) {
    _current = value;
    _changes.add(value);
  }

  Future<Result<void, ExchangeAccessFailure>> _save(ExchangeAccess next) async {
    final environment = _environment;
    final generation = _generation;
    if (environment == null) {
      return const Err(ExchangeAccessUnresolvedFailure());
    }
    final values = Map<bool, ExchangeAccess>.of(_values)..[environment] = next;
    final saved = await _repository.write(values);
    if (saved case Err(:final failure)) return Err(failure);
    _values = values;
    if (generation == _generation) _emit(next);
    return const Ok(null);
  }

  /// Call before starting account or socket effects, and again on environment change.
  Future<Result<ExchangeAccessOutcome, ExchangeAccessFailure>> initialize({
    required bool isTestnet,
    required ExchangeSessionFact session,
  }) {
    final generation = ++_generation;
    final sameEnvironment = _environment == isTestnet;
    _emit(
      sameEnvironment
          ? _current.copyWith(session: ExchangeSessionFact.resolving)
          : const ExchangeAccess(),
    );
    return _serial(() async {
      if (generation != _generation) {
        return const Ok(ExchangeAccessOutcome.stale);
      }
      _environment = null;
      final read = await _repository.read();
      if (generation != _generation) {
        return const Ok(ExchangeAccessOutcome.stale);
      }
      switch (read) {
        case Ok(:final value):
          _values = value;
        case Err(:final failure):
          return Err(failure);
      }
      _environment = isTestnet;
      _emit(
        (_values[isTestnet] ?? const ExchangeAccess()).copyWith(
          session: ExchangeSessionFact.resolving,
        ),
      );
      return _reconcile(session);
    });
  }

  Future<Result<ExchangeAccessOutcome, ExchangeAccessFailure>> reconcileSession(
    ExchangeSessionFact session, {
    int? generation,
  }) => _serial(() async {
    if (generation != null && generation != _generation) {
      return const Ok(ExchangeAccessOutcome.stale);
    }
    return _reconcile(session);
  });

  Future<Result<ExchangeAccessOutcome, ExchangeAccessFailure>> _reconcile(
    ExchangeSessionFact session,
  ) async {
    final generation = _generation;
    if (_environment == null) {
      return const Err(ExchangeAccessUnresolvedFailure());
    }
    if (_current.transition == ExchangeAccessTransition.disabling) {
      _emit(_current.copyWith(session: session));
      return const Err(ExchangeAccessIncompleteFailure());
    }
    if (session == ExchangeSessionFact.networkUnavailable) {
      final previous = _current.session;
      _emit(
        _current.copyWith(
          session: previous == ExchangeSessionFact.authenticated
              ? previous
              : ExchangeSessionFact.unavailable,
          isStale: true,
        ),
      );
      return const Ok(ExchangeAccessOutcome.applied);
    }
    var next = _current.copyWith(session: session, isStale: false);
    if (session == ExchangeSessionFact.authenticated) {
      next = next.copyWith(
        choice: ExchangeAccessChoice.enabled,
        transition: ExchangeAccessTransition.none,
        lastKnownAuthenticated: true,
      );
    } else if (session == ExchangeSessionFact.expired) {
      next = next.copyWith(
        choice: ExchangeAccessChoice.disabled,
        transition: ExchangeAccessTransition.none,
        lastKnownAuthenticated: false,
      );
    } else if (session == ExchangeSessionFact.anonymous) {
      next = next.copyWith(lastKnownAuthenticated: false);
      if (next.choice == ExchangeAccessChoice.unset) {
        next = next.copyWith(choice: ExchangeAccessChoice.disabled);
      }
      if (next.transition == ExchangeAccessTransition.enabling) {
        next = next.copyWith(transition: ExchangeAccessTransition.none);
      }
    }
    if (next.choice != _current.choice ||
        next.transition != _current.transition ||
        next.lastKnownAuthenticated != _current.lastKnownAuthenticated) {
      final saved = await _save(next.copyWith(revision: next.revision + 1));
      if (generation != _generation) {
        return const Ok(ExchangeAccessOutcome.stale);
      }
      if (saved case Err(:final failure)) {
        // A recognized session must not be presented as signed out on write failure.
        _emit(next);
        return Err(failure);
      }
    } else {
      _emit(next);
    }
    return const Ok(ExchangeAccessOutcome.applied);
  }

  /// Explicit wizard choice. OFF for an active session must go through disable.
  Future<Result<ExchangeAccessOutcome, ExchangeAccessFailure>> choose(
    bool enabled,
  ) => _serial(() async {
    if (_environment == null) {
      return const Err(ExchangeAccessUnresolvedFailure());
    }
    if (_current.transition == ExchangeAccessTransition.disabling ||
        (!enabled &&
            (_current.session != ExchangeSessionFact.anonymous ||
                _current.lastKnownAuthenticated))) {
      return const Err(ExchangeAccessIncompleteFailure());
    }
    final saved = await _save(
      _current.copyWith(
        choice: enabled
            ? ExchangeAccessChoice.enabled
            : ExchangeAccessChoice.disabled,
        transition: ExchangeAccessTransition.none,
        revision: _current.revision + 1,
      ),
    );
    return switch (saved) {
      Err(:final failure) => Err(failure),
      Ok() => const Ok(ExchangeAccessOutcome.applied),
    };
  });

  Future<Result<ExchangeAccessOutcome, ExchangeAccessFailure>>
  beginActivation() => _serial(() async {
    if (_environment == null) {
      return const Err(ExchangeAccessUnresolvedFailure());
    }
    if (_current.transition == ExchangeAccessTransition.disabling) {
      return const Err(ExchangeAccessIncompleteFailure());
    }
    if (_current.session == ExchangeSessionFact.authenticated) {
      return const Ok(ExchangeAccessOutcome.applied);
    }
    final saved = await _save(
      _current.copyWith(
        transition: ExchangeAccessTransition.enabling,
        revision: _current.revision + 1,
      ),
    );
    return switch (saved) {
      Err(:final failure) => Err(failure),
      Ok() => const Ok(ExchangeAccessOutcome.authenticationRequired),
    };
  });

  Future<Result<ExchangeAccessOutcome, ExchangeAccessFailure>>
  cancelActivation({int? generation}) => _serial(() async {
    if (generation != null && generation != _generation) {
      return const Ok(ExchangeAccessOutcome.stale);
    }
    if (_current.transition != ExchangeAccessTransition.enabling) {
      return const Ok(ExchangeAccessOutcome.stale);
    }
    final saved = await _save(
      _current.copyWith(
        transition: ExchangeAccessTransition.none,
        revision: _current.revision + 1,
      ),
    );
    return switch (saved) {
      Err(:final failure) => Err(failure),
      Ok() => const Ok(ExchangeAccessOutcome.cancelled),
    };
  });

  /// The cleanup must wait for in-flight authentication before deleting keys.
  Future<Result<ExchangeAccessOutcome, ExchangeAccessFailure>> disable(
    Future<bool> Function() cleanup,
  ) {
    final generation = ++_generation;
    return _serial(() async {
      if (_environment == null) {
        return const Err(ExchangeAccessUnresolvedFailure());
      }
      final pending = await _save(
        _current.copyWith(
          transition: ExchangeAccessTransition.disabling,
          revision: _current.revision + 1,
        ),
      );
      if (pending case Err(:final failure)) return Err(failure);
      bool cleared;
      try {
        cleared = await cleanup();
      } on Exception catch (_) {
        cleared = false;
      }
      if (generation != _generation) {
        return const Ok(ExchangeAccessOutcome.stale);
      }
      if (!cleared) return const Err(ExchangeAccessIncompleteFailure());
      final saved = await _save(
        _current.copyWith(
          choice: ExchangeAccessChoice.disabled,
          session: ExchangeSessionFact.anonymous,
          lastKnownAuthenticated: false,
          transition: ExchangeAccessTransition.none,
          revision: _current.revision + 1,
        ),
      );
      return switch (saved) {
        Err(:final failure) => Err(failure),
        Ok() => const Ok(ExchangeAccessOutcome.applied),
      };
    });
  }

  Future<void> dispose() => _changes.close();
}
