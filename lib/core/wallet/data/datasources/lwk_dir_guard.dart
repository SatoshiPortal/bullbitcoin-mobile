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
///
/// [run] is not reentrant for the same [dbPath] within one isolate: nesting
/// a second [run] call for the same wallet inside the first's `action`
/// (directly or transitively) deadlocks on the underlying [Lock]. No current
/// call site nests — `action` callbacks always run a single facade operation
/// to completion before returning.
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
///
/// Acquisition is check-then-write, not atomic: two isolates can both
/// observe no fresh holder and both write the marker, so this narrows the
/// cross-isolate race rather than closing it. That's acceptable today only
/// because the workmanager background task is unregistered elsewhere in this
/// codebase (see `ios/Runner/AppDelegate.swift`, `ios/Runner/Info.plist`'s
/// `BGTaskSchedulerPermittedIdentifiers`, and `Bull.initWorkmanager` in
/// main.dart — all three paused in lockstep with this), leaving a single
/// isolate in practice.
///
/// We do want to bring background sync back eventually, just hardened first.
/// Before re-registering that task anywhere, close these gaps found during
/// the final pre-merge review of the lock (2026-07):
///
///  1. Acquisition here is check-then-write, not atomic — replace with a
///     truly atomic acquire (e.g. `File.create(exclusive: true)`) so two
///     isolates can't both observe no holder and both write the marker.
///  2. `workmanager_android` hard-destroys its per-task `FlutterEngine` on
///     `onStopped()` (lost constraints, OS memory pressure, a racing
///     `cancelAll()`) without unwinding the Dart stack, so [release]'s
///     `finally` never runs. The leftover marker's owner id still carries
///     the live `$pid-` prefix (same OS process), so [_freshHolder]'s
///     crashed-process fast path can't catch it — the next caller waits out
///     the full [maxWait] instead of proceeding immediately. iOS's
///     `workmanager_apple` only cancels an `NSOperation`, so this is
///     Android-only. Needs either a WorkManager-side `onStopped` hook that
///     releases the marker, or a cheaper stale check on Android.
///  3. The native `lwk.Wallet` handle (a `RustOpaque` wrapping
///     `Mutex<lwk_wollet::Wollet>`, which keeps the cache directory open) is
///     never explicitly `dispose()`d in `LwkFacade` — it only becomes
///     GC-eligible when the local variable goes out of scope, and actual
///     native cleanup depends on an unpredictable `NativeFinalizer` run. A
///     background task firing back-to-back with a foreground call could
///     reacquire this guard and open a fresh `Wollet` on the same `dbPath`
///     before the previous handle's finalizer has actually run, reproducing
///     a narrower version of `UpdateOnDifferentStatus`. Call `dispose()`
///     explicitly inside `LwkFacade`'s guarded callbacks instead of relying
///     on GC.
///  4. `test/core_test/wallet/data/datasources/lwk_dir_guard_test.dart` only
///     exercises same-isolate/happy-path acquisition — no test drives a
///     genuine second owner contending for the marker, the refresh-timer
///     keep-alive across a long hold, or the [maxWait]-exceeded
///     proceed-anyway fallback. Add those before trusting this under real
///     cross-isolate load.
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
    final owner = content['owner'] as String?;
    // Both engines that could ever hold this marker share one OS process, so
    // an owner id whose pid prefix differs from ours can only be a crashed
    // process's leftover — treat it as stale immediately instead of waiting
    // out `staleAfter`, which is what let a leftover marker freeze this exact
    // startup path for up to `maxWait`.
    if (owner == null || !owner.startsWith('$pid-')) return null;
    final ts = DateTime.tryParse(content['ts'] as String? ?? '');
    if (ts == null || DateTime.now().difference(ts) > staleAfter) return null;
    return owner;
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
