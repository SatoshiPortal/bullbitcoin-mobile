import 'package:bull_payjoin/src/engine/directory_poller.dart';
import 'package:bull_payjoin/src/engine/payjoin_constants.dart';
import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';

const _interval = Duration(seconds: PayjoinConstants.directoryPollingInterval);
const _id = 'session-1';

void main() {
  late List<String> found;
  late int expired;
  late List<Duration> startedAt;

  setUp(() {
    found = [];
    expired = 0;
    startedAt = [];
  });

  /// Runs [body] with a poller on the fake clock, polling a session that
  /// expires [lifetime] from the start and whose polls all answer [outcome].
  void withPoller(
    void Function(FakeAsync async, DirectoryPoller<String> poller) body, {
    DirectoryPollResult<String> answer = const DirectoryPollResult(
      DirectoryPollOutcome.empty,
    ),
    Duration lifetime = const Duration(hours: 1),
  }) {
    fakeAsync((async) {
      final origin = DateTime(2026, 10, 20);
      final poller = DirectoryPoller<String>(
        now: () => origin.add(async.elapsed),
      );
      poller.start(
        id: _id,
        expiresAt: origin.add(lifetime),
        poll: (_) async {
          startedAt.add(async.elapsed);
          return answer;
        },
        onFound: found.add,
        onExpired: () => expired++,
      );
      body(async, poller);
      poller.dispose();
      async.flushTimers();
    });
  }

  test('a session is polled every interval', () {
    withPoller((async, poller) {
      async.elapse(_interval * 3);
      expect(startedAt, [_interval, _interval * 2, _interval * 3]);
    });
  });

  test('a found value is handed on once and polling stops', () {
    withPoller((async, poller) {
      async.elapse(_interval * 3);
      expect(found, ['request']);
      expect(startedAt, [_interval]);
    }, answer: const DirectoryPollResult.found('request'));
  });

  test('the expiry is handed on at the first tick past it', () {
    withPoller((async, poller) {
      async.elapse(_interval * 3);
      expect(expired, 1);
      expect(startedAt, [_interval]);
    }, lifetime: _interval + const Duration(seconds: 1));
  });

  test('stop ends the polling', () {
    withPoller((async, poller) {
      async.elapse(_interval);
      poller.stop(_id);
      async.elapse(_interval * 3);
      expect(startedAt, [_interval]);
    });
  });
}
