import 'package:bb_mobile/features/sp/domain/sp_session_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SpSessionGuard guard;

  setUp(() {
    guard = SpSessionGuard();
  });

  test('runs bodies one at a time, in the order they were submitted', () async {
    final order = <String>[];

    Future<void> slow(String name, int ticks) => guard.exclusive(() async {
      order.add('$name start');
      for (var i = 0; i < ticks; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      order.add('$name end');
    });

    final first = slow('a', 5);
    final second = slow('b', 1);
    await Future.wait([first, second]);

    expect(order, ['a start', 'a end', 'b start', 'b end']);
  });

  test('a failing body still lets the next one run', () async {
    // The queue must not stay poisoned: a failed revoke cannot block every
    // later save.
    final failing = guard.exclusive(() async => throw StateError('boom'));

    await expectLater(failing, throwsA(isA<StateError>()));
    expect(await guard.exclusive(() async => 7), 7);
  });

  test('the failure reaches its own caller, not the next one', () async {
    final failing = guard.exclusive(() async => throw StateError('boom'));
    final next = guard.exclusive(() async => 'ok');

    await expectLater(failing, throwsA(isA<StateError>()));
    expect(await next, 'ok');
  });

  test('a body queued after the first has finished runs at once', () async {
    expect(await guard.exclusive(() async => 1), 1);
    expect(await guard.exclusive(() async => 2), 2);
  });
}
