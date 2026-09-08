import 'entities/tor_route.dart';

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

  Future<TorRouteLease> acquire({
    required String key,
    required Future<TorRoute> Function() open,
    required Future<void> Function() close,
  }) async {
    final existing = _entries[key];
    if (existing != null) {
      existing.references++;
      return TorRouteLease(existing.route, () => _release(key, existing));
    }
    final pending = _acquisitions[key] ??= _openAndStore(key, open, close);
    final entry = await pending;
    entry.references++;
    return TorRouteLease(entry.route, () => _release(key, entry));
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

  Future<void> _release(String key, _Entry entry) async {
    if (--entry.references > 0) return;
    if (identical(_entries[key], entry)) _entries.remove(key);
    await entry.close();
  }
}

final class _Entry {
  final TorRoute route;
  final Future<void> Function() _onClose;
  int references = 0;
  Future<void>? _closing;

  _Entry(this.route, this._onClose);

  Future<void> close() => _closing ??= _onClose();
}
