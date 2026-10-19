import 'package:bull_payjoin/src/engine/directory_poller.dart';
import 'package:bull_payjoin/src/engine/payjoin_constants.dart';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';

const _spacing = Duration(seconds: PayjoinConstants.directoryMinPollSpacingSec);
const _id = 'session-1';

/// A fake directory poll: each call takes the next scripted step, records
/// when it started on the fake clock, and hands out the token it was given.
class _ScriptedPoll {
  final FakeAsync _async;
  final List<Future<DirectoryPollResult<String>> Function(CancelToken)> _steps;
  final List<Duration> startedAt = [];
  final List<CancelToken> tokens = [];

  _ScriptedPoll(this._async, this._steps);

  Future<DirectoryPollResult<String>> call(CancelToken cancelToken) {
    startedAt.add(_async.elapsed);
    tokens.add(cancelToken);
    if (_steps.isEmpty) return Future.value(_result(.empty));
    return _steps.removeAt(0)(cancelToken);
  }
}

DirectoryPollResult<String> _result(DirectoryPollOutcome outcome) =>
    DirectoryPollResult(outcome);

/// A step that answers [outcome] after [after].
Future<DirectoryPollResult<String>> Function(CancelToken) _after(
  Duration after,
  DirectoryPollOutcome outcome,
) =>
    (_) => Future.delayed(after, () => _result(outcome));

/// A step held like an empty GET until its token is cancelled.
Future<DirectoryPollResult<String>> _heldUntilCancelled(
  CancelToken cancelToken,
) async => throw await cancelToken.whenCancel;

void main() {
  late List<String> found;
  late int expired;

  setUp(() {
    found = [];
    expired = 0;
  });

  /// Runs [body] with a poller on the fake clock and a session that expires
  /// [lifetime] from the start.
  void withPoller(
    void Function(
      FakeAsync async,
      DirectoryPoller<String> poller,
      void Function(_ScriptedPoll poll) start,
    )
    body, {
    Duration lifetime = const Duration(hours: 1),
  }) {
    fakeAsync((async) {
      final origin = DateTime(2026, 10, 20);
      final poller = DirectoryPoller<String>(
        now: () => origin.add(async.elapsed),
        elapsed: () => async.elapsed,
      );
      void start(_ScriptedPoll poll) => poller.start(
        id: _id,
        expiresAt: origin.add(lifetime),
        poll: poll.call,
        onFound: found.add,
        onExpired: () => expired++,
      );
      body(async, poller, start);
      poller.dispose();
      async.flushTimers();
    });
  }

  test('the first poll goes out at once', () {
    withPoller((async, poller, start) {
      final poll = _ScriptedPoll(async, []);
      start(poll);
      async.elapse(Duration.zero);
      expect(poll.startedAt, [Duration.zero]);
    });
  });

  test('an empty reply the directory held is followed at once', () {
    withPoller((async, poller, start) {
      final poll = _ScriptedPoll(async, [
        _after(const Duration(seconds: 30), .empty),
      ]);
      start(poll);
      async.elapse(const Duration(seconds: 30));
      expect(poll.startedAt, [Duration.zero, const Duration(seconds: 30)]);
    });
  });

  test('an early empty reply waits out the spacing', () {
    withPoller((async, poller, start) {
      final poll = _ScriptedPoll(async, [
        _after(const Duration(milliseconds: 200), .empty),
      ]);
      start(poll);
      async.elapse(_spacing - const Duration(milliseconds: 1));
      expect(poll.startedAt, [Duration.zero]);
      async.elapse(const Duration(milliseconds: 1));
      expect(poll.startedAt, [Duration.zero, _spacing]);
    });
  });

  test('a failed poll waits the full spacing after it ends', () {
    withPoller((async, poller, start) {
      final poll = _ScriptedPoll(async, [
        _after(const Duration(seconds: 30), .failed),
      ]);
      start(poll);
      async.elapse(const Duration(seconds: 30) + _spacing);
      expect(poll.startedAt, [
        Duration.zero,
        const Duration(seconds: 30) + _spacing,
      ]);
    });
  });

  test('a poll that throws counts as a failure', () {
    withPoller((async, poller, start) {
      final poll = _ScriptedPoll(async, [(_) async => throw StateError('x')]);
      start(poll);
      async.elapse(_spacing);
      expect(poll.startedAt, [Duration.zero, _spacing]);
      expect(expired, 0);
    });
  });

  test('a found value is handed on once and polling stops', () {
    withPoller((async, poller, start) {
      final poll = _ScriptedPoll(async, [
        (_) async => const DirectoryPollResult.found('request'),
      ]);
      start(poll);
      async.elapse(_spacing * 3);
      expect(found, ['request']);
      expect(poll.startedAt, hasLength(1));
    });
  });

  test('an expired poll hands the expiry on once and polling stops', () {
    withPoller((async, poller, start) {
      final poll = _ScriptedPoll(async, [_after(Duration.zero, .expired)]);
      start(poll);
      async.elapse(_spacing * 3);
      expect(expired, 1);
      expect(poll.startedAt, hasLength(1));
    });
  });

  test('a wait never runs past the expiry', () {
    withPoller((async, poller, start) {
      final poll = _ScriptedPoll(async, [_after(Duration.zero, .failed)]);
      start(poll);
      async.elapse(
        const Duration(seconds: 2) - const Duration(milliseconds: 1),
      );
      expect(expired, 0);
      async.elapse(const Duration(milliseconds: 1));
      expect(expired, 1);
      // The expiry is noticed before polling again.
      expect(poll.startedAt, hasLength(1));
    }, lifetime: const Duration(seconds: 2));
  });

  test('the expiry cancels a held poll and settles the session', () {
    withPoller((async, poller, start) {
      final poll = _ScriptedPoll(async, [_heldUntilCancelled]);
      start(poll);
      async.elapse(
        const Duration(seconds: 2) - const Duration(milliseconds: 1),
      );
      expect(poll.tokens.single.isCancelled, isFalse);
      async.elapse(const Duration(milliseconds: 1));
      expect(poll.tokens.single.isCancelled, isTrue);
      expect(expired, 1);
      async.elapse(_spacing * 3);
      expect(poll.startedAt, hasLength(1));
    }, lifetime: const Duration(seconds: 2));
  });

  test('a session already past its expiry expires without polling', () {
    withPoller((async, poller, start) {
      final poll = _ScriptedPoll(async, []);
      start(poll);
      async.elapse(Duration.zero);
      expect(expired, 1);
      expect(poll.startedAt, isEmpty);
    }, lifetime: Duration.zero);
  });

  test('a stale session stops polling but keeps its expiry', () {
    withPoller((async, poller, start) {
      final poll = _ScriptedPoll(async, [_after(Duration.zero, .stale)]);
      start(poll);
      async.elapse(
        const Duration(seconds: 10) - const Duration(milliseconds: 1),
      );
      expect(poll.startedAt, hasLength(1));
      expect(expired, 0);
      // The expiry still reaches the engine, which settles the session, and
      // no request goes out for it.
      async.elapse(const Duration(milliseconds: 1));
      expect(expired, 1);
      expect(poll.startedAt, hasLength(1));
      expect(found, isEmpty);
    }, lifetime: const Duration(seconds: 10));
  });

  test('stop during a wait cancels the next poll', () {
    withPoller((async, poller, start) {
      final poll = _ScriptedPoll(async, [_after(Duration.zero, .failed)]);
      start(poll);
      async.elapse(Duration.zero);
      poller.stop(_id);
      async.elapse(_spacing * 3);
      expect(poll.startedAt, hasLength(1));
    });
  });

  test('stop during a poll drops what it finds', () {
    withPoller((async, poller, start) {
      final poll = _ScriptedPoll(async, [
        (_) => Future.delayed(
          const Duration(seconds: 1),
          () => const DirectoryPollResult.found('request'),
        ),
      ]);
      start(poll);
      async.elapse(const Duration(milliseconds: 500));
      poller.stop(_id);
      async.elapse(_spacing * 3);
      expect(found, isEmpty);
      expect(poll.startedAt, hasLength(1));
    });
  });

  test('stop cancels the request in flight', () {
    withPoller((async, poller, start) {
      final poll = _ScriptedPoll(async, [_heldUntilCancelled]);
      start(poll);
      async.elapse(const Duration(seconds: 1));
      poller.stop(_id);
      expect(poll.tokens.single.isCancelled, isTrue);
      async.elapse(_spacing * 3);
      expect(poll.startedAt, hasLength(1));
      expect(expired, 0);
    });
  });

  test('dispose cancels the request in flight and refuses new sessions', () {
    withPoller((async, poller, start) {
      final poll = _ScriptedPoll(async, [_heldUntilCancelled]);
      start(poll);
      async.elapse(const Duration(seconds: 1));
      poller.dispose();
      expect(poll.tokens.single.isCancelled, isTrue);

      final late = _ScriptedPoll(async, []);
      start(late);
      async.elapse(_spacing * 3);
      expect(late.startedAt, isEmpty);
      expect(expired, 0);
    });
  });

  test('a restart after stop polls as soon as the old request drains', () {
    withPoller((async, poller, start) {
      final first = _ScriptedPoll(async, [_heldUntilCancelled]);
      start(first);
      async.elapse(const Duration(seconds: 1));

      poller.stop(_id);
      final second = _ScriptedPoll(async, [
        _after(const Duration(seconds: 30), .empty),
      ]);
      start(second);
      async.elapse(Duration.zero);

      expect(first.tokens.single.isCancelled, isTrue);
      expect(second.startedAt, [const Duration(seconds: 1)]);
    });
  });

  /// A step that ignores its token and only returns after [after], like a
  /// transport slow to unwind a cancelled request.
  Future<DirectoryPollResult<String>> Function(CancelToken) slowToUnwind(
    Duration after,
  ) =>
      (_) => Future.delayed(after, () => _result(.empty));

  test('a replacement that drains past its expiry expires', () {
    withPoller((async, poller, start) {
      final old = _ScriptedPoll(async, [
        slowToUnwind(const Duration(seconds: 10)),
      ]);
      start(old);
      async.elapse(const Duration(seconds: 1));

      poller.stop(_id);
      final replacement = _ScriptedPoll(async, [
        (_) async => const DirectoryPollResult.found('request'),
      ]);
      start(replacement);
      async.elapse(const Duration(seconds: 9));

      expect(replacement.startedAt, isEmpty);
      expect(found, isEmpty);
      expect(expired, 1);
    }, lifetime: const Duration(seconds: 10));
  });

  test('the spacing counts from the poll, not from the drain before it', () {
    withPoller((async, poller, start) {
      final old = _ScriptedPoll(async, [
        slowToUnwind(const Duration(seconds: 4)),
      ]);
      start(old);
      async.elapse(const Duration(seconds: 1));

      poller.stop(_id);
      final replacement = _ScriptedPoll(async, [_after(Duration.zero, .empty)]);
      start(replacement);
      async.elapse(const Duration(seconds: 3) + _spacing);

      expect(replacement.startedAt, [
        const Duration(seconds: 4),
        const Duration(seconds: 4) + _spacing,
      ]);
    });
  });

  test('a repeated start leaves a held poll alone', () {
    withPoller((async, poller, start) {
      final first = _ScriptedPoll(async, [
        (_) => Future.delayed(
          const Duration(seconds: 20),
          () => const DirectoryPollResult.found('request'),
        ),
      ]);
      start(first);
      async.elapse(const Duration(seconds: 1));

      // The app came back to the foreground and resumed its sessions.
      final again = _ScriptedPoll(async, []);
      start(again);
      async.elapse(const Duration(seconds: 19));

      expect(again.startedAt, isEmpty);
      expect(first.tokens.single.isCancelled, isFalse);
      expect(found, ['request']);
    });
  });

  test('a repeated start keeps the wait after a failure', () {
    withPoller((async, poller, start) {
      final first = _ScriptedPoll(async, [_after(Duration.zero, .failed)]);
      start(first);
      async.elapse(const Duration(seconds: 1));

      start(_ScriptedPoll(async, []));
      async.elapse(
        _spacing - const Duration(seconds: 1) - const Duration(milliseconds: 1),
      );
      expect(first.startedAt, [Duration.zero]);
      async.elapse(const Duration(milliseconds: 1));
      expect(first.startedAt, [Duration.zero, _spacing]);
    });
  });
}
