import 'dart:async';

import 'package:access/src/domain/access_lock_policy.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';

final class _Timers {
  final scheduled = <({Duration after, void Function() run, _Fake timer})>[];

  Timer create(Duration after, void Function() run) {
    final timer = _Fake();
    scheduled.add((after: after, run: run, timer: timer));
    return timer;
  }
}

final class _Fake implements Timer {
  var cancelled = false;
  @override
  void cancel() => cancelled = true;
  @override
  bool get isActive => !cancelled;
  @override
  int get tick => 0;
}

void main() {
  late DateTime clock;
  late _Timers timers;
  late int locks;
  late AccessLockPolicy policy;

  setUp(() {
    clock = DateTime.utc(2026, 11, 25);
    timers = _Timers();
    locks = 0;
    policy = AccessLockPolicy(
      onLock: () async => locks++,
      now: () => clock,
      timer: timers.create,
    );
  });

  test('the delay is sixty seconds by default', () {
    expect(accessBackgroundLockDelay, const Duration(seconds: 60));
  });

  test('inactive alone starts nothing and locks nothing', () {
    policy.onLifecycle(AppLifecycleState.inactive);
    policy.onLifecycle(AppLifecycleState.resumed);
    expect(timers.scheduled, isEmpty);
    expect(locks, 0);
  });

  test('the timer firing in the background locks once', () {
    policy.onLifecycle(AppLifecycleState.inactive);
    policy.onLifecycle(AppLifecycleState.paused);
    policy.onLifecycle(AppLifecycleState.hidden);
    expect(timers.scheduled.single.after, accessBackgroundLockDelay);
    timers.scheduled.single.run();
    expect(locks, 1);
  });

  test('returning within the delay cancels the lock', () {
    policy.onLifecycle(AppLifecycleState.paused);
    clock = clock.add(const Duration(seconds: 59));
    policy.onLifecycle(AppLifecycleState.resumed);
    expect(timers.scheduled.single.timer.cancelled, isTrue);
    expect(locks, 0);
  });

  test('a suspended timer is covered by the clock on return', () {
    policy.onLifecycle(AppLifecycleState.paused);
    clock = clock.add(const Duration(seconds: 61));
    policy.onLifecycle(AppLifecycleState.resumed);
    expect(locks, 1);
  });

  test('resume does not lock a second time when the timer already fired', () {
    policy.onLifecycle(AppLifecycleState.paused);
    clock = clock.add(const Duration(seconds: 61));
    timers.scheduled.single.run();
    policy.onLifecycle(AppLifecycleState.resumed);
    expect(locks, 1);
  });

  test('a flow that leaves the app on purpose holds the lock off', () {
    final scanner = policy.suspendAutoLock('scanner');
    policy.onLifecycle(AppLifecycleState.paused);
    clock = clock.add(const Duration(seconds: 90));
    policy.onLifecycle(AppLifecycleState.resumed);
    expect(locks, 0);

    scanner.release();
    scanner.release();
    expect(policy.isSuspended, isFalse);
    expect(locks, 0, reason: 'releasing never locks retroactively');

    policy.onLifecycle(AppLifecycleState.paused);
    clock = clock.add(const Duration(seconds: 61));
    policy.onLifecycle(AppLifecycleState.resumed);
    expect(locks, 1);
  });

  test('two suspensions are independent', () {
    final a = policy.suspendAutoLock('scanner');
    final b = policy.suspendAutoLock('biometrics');
    a.release();
    expect(policy.isSuspended, isTrue);
    b.release();
    expect(policy.isSuspended, isFalse);
  });
}
