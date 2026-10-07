import 'dart:async';

import 'entities/tor_route.dart';

enum TorRoutePoolEventType { opened, attached, closeFailed, closed }

final class TorRoutePoolEvent {
  final TorRoutePoolEventType type;
  final TorSource source;
  final int holders;

  const TorRoutePoolEvent(this.type, this.source, this.holders);

  String get logMessage =>
      'recoverbull.tor.route.${type.name} source=${source.name} holders=$holders';
}

final class TorRouteLease {
  final TorRoute route;
  final Future<void> Function() _onRelease;
  Future<void>? _released;

  TorRouteLease(this.route, this._onRelease);

  Future<void> release() => _released ??= _onRelease();
}

abstract interface class TorRoutePoolTimer {
  void cancel();
}

typedef TorRoutePoolTimerFactory =
    TorRoutePoolTimer Function(Duration duration, void Function() callback);

final class _DartTorRoutePoolTimer implements TorRoutePoolTimer {
  final Timer _timer;

  _DartTorRoutePoolTimer(Duration duration, void Function() callback)
    : _timer = Timer(duration, callback);

  @override
  void cancel() => _timer.cancel();
}

/// Shares one verified route per source key and closes it after the last lease.
/// The composition root supplies the key so embedded and external routes never mix.
///
/// Invalidation retires the current route: holders keep it until they release,
/// while new acquisitions open a fresh route alongside it. Each route is an
/// independent session, so a stale lease never blocks the next generation.
final class TorRoutePool {
  final Duration gracePeriod;
  final TorRoutePoolTimerFactory timerFactory;
  final Map<String, _Entry> _entries = {};
  final Map<String, Future<_Entry>> _acquisitions = {};
  final Map<String, Future<void>> _closures = {};
  final Set<_Entry> _retired = {};
  bool _closed = false;

  TorRoutePool({
    this.gracePeriod = const Duration(seconds: 90),
    this.timerFactory = _defaultTimerFactory,
  });

  static TorRoutePoolTimer _defaultTimerFactory(
    Duration duration,
    void Function() callback,
  ) => _DartTorRoutePoolTimer(duration, callback);

  Future<TorRouteLease> acquire({
    required String key,
    required Future<TorRoute> Function() open,
    required Future<void> Function() close,
    void Function(TorRoutePoolEvent event)? onEvent,
  }) async {
    if (_closed) throw StateError('TorRoutePool is closed');
    final existing = _entries[key];
    if (existing != null && !existing.isClosing) {
      existing.cancelGrace();
      existing.references++;
      _emit(
        onEvent,
        TorRoutePoolEvent(
          TorRoutePoolEventType.attached,
          existing.route.source,
          existing.references,
        ),
      );
      return TorRouteLease(
        existing.route,
        () => _release(key, existing, onEvent),
      );
    }
    final acquisition = _acquisitions[key];
    final previousClose = _closures[key];
    if (previousClose != null) {
      await previousClose;
      return acquire(key: key, open: open, close: close, onEvent: onEvent);
    }
    late final Future<_Entry> pending;
    if (acquisition == null) {
      pending = _openAndStore(key, open, close);
      _acquisitions[key] = pending;
    } else {
      pending = acquisition;
    }
    final entry = await pending;
    if (!identical(_entries[key], entry) || entry.isClosing) {
      return acquire(key: key, open: open, close: close, onEvent: onEvent);
    }
    entry.references++;
    _emit(
      onEvent,
      TorRoutePoolEvent(
        acquisition == null
            ? TorRoutePoolEventType.opened
            : TorRoutePoolEventType.attached,
        entry.route.source,
        entry.references,
      ),
    );
    return TorRouteLease(entry.route, () => _release(key, entry, onEvent));
  }

  Future<_Entry> _openAndStore(
    String key,
    Future<TorRoute> Function() open,
    Future<void> Function() close,
  ) async {
    try {
      final route = await open();
      if (_closed) {
        try {
          await close();
        } finally {
          _acquisitions.remove(key);
        }
        throw StateError('TorRoutePool is closed');
      }
      final entry = _Entry(route, close);
      _entries[key] = entry;
      _acquisitions.remove(key);
      return entry;
    } catch (_) {
      _acquisitions.remove(key);
      rethrow;
    }
  }

  Future<void> _release(
    String key,
    _Entry entry,
    void Function(TorRoutePoolEvent event)? onEvent,
  ) async {
    if (--entry.references > 0) return;
    if (entry.isClosing) return;
    entry.onEvent = onEvent;
    if (_retired.remove(entry)) {
      await _closeEntry(entry);
      return;
    }
    if (_closed) {
      await _beginClose(key, entry);
      return;
    }
    entry.scheduleGrace(
      gracePeriod,
      timerFactory,
      () => unawaited(_beginClose(key, entry)),
    );
  }

  Future<void> invalidate({String? key}) async {
    final entries = _entries.entries
        .where((item) => key == null || item.key == key)
        .map((item) => (item.key, item.value))
        .toList();
    for (final (entryKey, entry) in entries) {
      if (entry.references == 0) {
        await _beginClose(entryKey, entry);
      } else if (identical(_entries[entryKey], entry) && !entry.isClosing) {
        _entries.remove(entryKey);
        _retired.add(entry);
      }
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final acquisition in _acquisitions.values.toList()) {
      try {
        await acquisition;
      } catch (_) {
        // A pending acquisition owns cleanup of a route opened after shutdown.
      }
    }
    final entries = _entries.entries
        .map((item) => (item.key, item.value))
        .toList();
    final retired = _retired.toList();
    _retired.clear();
    await Future.wait([
      ...entries.map((item) => _beginClose(item.$1, item.$2)),
      ...retired.map(_closeEntry),
    ]);
    await Future.wait(_closures.values.toList());
  }

  /// Never throws: a failing consumer close is reported as [closeFailed] and
  /// the route is still considered closed, so grace timers and pool shutdown
  /// cannot surface it as an unhandled error.
  ///
  /// [closeFailed]: TorRoutePoolEventType.closeFailed
  Future<void> _closeEntry(_Entry entry) async {
    entry.cancelGrace();
    try {
      await entry.close();
    } catch (_) {
      // The error may describe the route; only its occurrence is reported.
      _emit(
        entry.onEvent,
        TorRoutePoolEvent(
          TorRoutePoolEventType.closeFailed,
          entry.route.source,
          0,
        ),
      );
    }
    _emit(
      entry.onEvent,
      TorRoutePoolEvent(TorRoutePoolEventType.closed, entry.route.source, 0),
    );
  }

  Future<void> _beginClose(String key, _Entry entry) async {
    if (!identical(_entries[key], entry) || entry.isClosing) {
      await (_closures[key] ?? Future<void>.value());
      return;
    }
    final closing = _closeEntry(entry);
    _closures[key] = closing;
    try {
      await closing;
    } finally {
      if (identical(_entries[key], entry)) _entries.remove(key);
      if (identical(_closures[key], closing)) _closures.remove(key);
    }
  }

  void _emit(
    void Function(TorRoutePoolEvent event)? onEvent,
    TorRoutePoolEvent event,
  ) {
    try {
      onEvent?.call(event);
    } catch (_) {
      // Pool diagnostics must never alter route ownership.
    }
  }
}

final class _Entry {
  final TorRoute route;
  final Future<void> Function() _onClose;
  int references = 0;
  Future<void>? _closing;
  TorRoutePoolTimer? _graceTimer;
  void Function(TorRoutePoolEvent event)? onEvent;

  _Entry(this.route, this._onClose);

  bool get isClosing => _closing != null;

  Future<void> close() => _closing ??= _onClose();

  void scheduleGrace(
    Duration duration,
    TorRoutePoolTimerFactory timerFactory,
    void Function() onExpire,
  ) {
    _graceTimer?.cancel();
    _graceTimer = timerFactory(duration, onExpire);
  }

  void cancelGrace() {
    _graceTimer?.cancel();
    _graceTimer = null;
  }
}
