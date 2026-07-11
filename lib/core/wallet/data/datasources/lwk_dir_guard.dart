import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:synchronized/synchronized.dart';

/// Serializes access to one on-disk LWK wollet cache directory.
///
/// Two wollets open on the same cache directory race each other and
/// `apply_update` throws `UpdateOnDifferentStatus`, so every caller must run
/// through [run] for a given [dbPath] before touching the wollet. Access is
/// serialized within the isolate via a per-path [Lock], and across isolates
/// (the workmanager background isolate runs in the same process as the
/// foreground engine, where an in-process Lock alone cannot serialize two
/// isolates) via a freshness-gated marker file.
class LwkDirGuard {
  static final Map<String, Lock> _dirLocks = {};

  static Future<T> run<T>(String dbPath, Future<T> Function() action) async {
    final lock = _dirLocks.putIfAbsent(dbPath, Lock.new);
    return lock.synchronized(() async {
      final marker = CrossIsolateDirMarker(dbPath);
      await marker.acquire();
      try {
        return await action();
      } finally {
        await marker.release();
      }
    });
  }
}

/// Advisory cross-isolate guard for one wollet cache directory.
///
/// Both engines (main + workmanager) live in one process, so neither Dart
/// locks nor fcntl locks (process-owned) can serialize them; instead each
/// holder writes `<dbPath>.lwkguard` with its owner id and a timestamp it
/// refreshes while working. Waiters poll until the marker is gone or stale.
/// The stale TTL keeps a crashed holder from wedging the app, and the wait
/// deadline prefers a (rare, recoverable) collision over blocking forever.
class CrossIsolateDirMarker {
  static const staleAfter = Duration(seconds: 60);
  static const maxWait = Duration(seconds: 45);
  static const refreshEvery = Duration(seconds: 20);
  static const pollEvery = Duration(milliseconds: 200);

  static final String _isolateOwner =
      '$pid-${Isolate.current.hashCode}-'
      '${DateTime.now().microsecondsSinceEpoch}';

  final String _markerPath;
  Timer? _refreshTimer;

  CrossIsolateDirMarker(String dbPath) : _markerPath = '$dbPath.lwkguard';

  File get _file => File(_markerPath);

  Future<void> acquire() async {
    final deadline = DateTime.now().add(maxWait);
    while (true) {
      final holder = await _freshHolder();
      if (holder == null || holder == _isolateOwner) break;
      if (DateTime.now().isAfter(deadline)) {
        log.warning(
          'LWK dir guard: still held by $holder after $maxWait — '
          'proceeding anyway to avoid wedging the app',
        );
        break;
      }
      await Future<void>.delayed(pollEvery);
    }
    await _write();
    _refreshTimer = Timer.periodic(refreshEvery, (_) => _write());
  }

  Future<void> release() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    try {
      final content = await _readContent();
      if (content?['owner'] == _isolateOwner) await _file.delete();
    } catch (_) {
      // Best effort; a leftover marker expires via the stale TTL.
    }
  }

  Future<String?> _freshHolder() async {
    final content = await _readContent();
    if (content == null) return null;
    final ts = DateTime.tryParse(content['ts'] as String? ?? '');
    if (ts == null || DateTime.now().difference(ts) > staleAfter) return null;
    return content['owner'] as String?;
  }

  Future<Map<String, dynamic>?> _readContent() async {
    try {
      if (!await _file.exists()) return null;
      return jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      // Torn marker write from the other isolate; treat as absent.
      return null;
    }
  }

  Future<void> _write() async {
    try {
      await _file.writeAsString(
        jsonEncode({
          'owner': _isolateOwner,
          'ts': DateTime.now().toIso8601String(),
        }),
        flush: true,
      );
    } catch (e) {
      log.warning('LWK dir guard: failed to write marker', error: e);
    }
  }
}
