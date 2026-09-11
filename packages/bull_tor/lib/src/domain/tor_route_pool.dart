import 'entities/tor_route.dart';

enum TorRoutePoolEventType { opened, attached, closed }

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

/// Shares one verified route per source key and closes it after the last lease.
/// The composition root supplies the key so embedded and external routes never mix.
final class TorRoutePool {
  final Map<String, _Entry> _entries = {};
  final Map<String, Future<_Entry>> _acquisitions = {};
  final Map<String, Future<void>> _closures = {};

  Future<TorRouteLease> acquire({
    required String key,
    required Future<TorRoute> Function() open,
    required Future<void> Function() close,
    void Function(TorRoutePoolEvent event)? onEvent,
  }) async {
    while (true) {
      final existing = _entries[key];
      if (existing != null && !existing.isClosing) {
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
        continue;
      }
      late final Future<_Entry> pending;
      if (acquisition == null) {
        pending = _openAndStore(key, open, close);
        _acquisitions[key] = pending;
      } else {
        pending = acquisition;
      }
      final entry = await pending;
      if (!identical(_entries[key], entry) || entry.isClosing) continue;
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
  }

  Future<_Entry> _openAndStore(
    String key,
    Future<TorRoute> Function() open,
    Future<void> Function() close,
  ) async {
    try {
      final entry = _Entry(await open(), close);
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
    if (identical(_entries[key], entry)) _entries.remove(key);
    final closing = entry.close();
    _closures[key] = closing;
    try {
      await closing;
      _emit(
        onEvent,
        TorRoutePoolEvent(TorRoutePoolEventType.closed, entry.route.source, 0),
      );
    } finally {
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

  _Entry(this.route, this._onClose);

  bool get isClosing => _closing != null;

  Future<void> close() => _closing ??= _onClose();
}
