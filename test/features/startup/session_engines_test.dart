import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:startup/startup.dart';

final class _Probe {
  final stops = <Completer<void>>[];
  var resumes = 0;
  var suspends = 0;
  Object? failure;

  SessionEngine engine() => SessionEngine(
    name: 'probe',
    suspend: () {
      suspends++;
      if (failure case final error?) throw error;
      final gate = Completer<void>();
      stops.add(gate);
      return gate.future;
    },
    resume: () => resumes++,
  );
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _Probe probe;
  late SessionEngines engines;

  setUp(() {
    probe = _Probe();
    engines = SessionEngines([probe.engine()])..markStarted();
  });

  test(
    'lock revokes synchronously and unlock resumes once after the stop',
    () async {
      engines.lock();
      expect(probe.suspends, 1, reason: 'suspend ran before lock returned');

      engines.unlock();
      await _settle();
      expect(probe.resumes, 0, reason: 'the stop is not confirmed yet');

      probe.stops.single.complete();
      await _settle();
      expect(probe.resumes, 1);

      engines.unlock();
      await _settle();
      expect(probe.resumes, 1, reason: 'one resume per suspension');
    },
  );

  test(
    'unlock B then lock before the late stop of A resumes nothing',
    () async {
      engines.lock();
      engines.unlock();
      engines.lock();
      expect(
        probe.suspends,
        1,
        reason: 'no second stop beside the pending one',
      );

      probe.stops.single.complete();
      await _settle();
      expect(probe.resumes, 0);

      engines.unlock();
      await _settle();
      expect(probe.resumes, 1, reason: 'only the current session resumes');
    },
  );

  test('a stop that never confirms keeps the engine closed', () async {
    engines.lock();
    engines.unlock();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(probe.resumes, 0);
    expect(probe.suspends, 1);
  });

  test('a failed stop keeps the engine closed for good', () async {
    probe.failure = StateError('native close failed');
    engines.lock();
    engines.unlock();
    await _settle();
    engines.lock();
    engines.unlock();
    await _settle();
    expect(probe.resumes, 0);
  });

  test('an engine never started is not resumed by an unlock', () async {
    final idle = _Probe();
    final fresh = SessionEngines([idle.engine()]);
    fresh.lock();
    fresh.unlock();
    await _settle();
    expect(idle.suspends, 0);
    expect(idle.resumes, 0);
  });

  test('untilUnlocked waits for the unlock', () async {
    engines.lock();
    var released = false;
    unawaited(engines.untilUnlocked().then((_) => released = true));
    await _settle();
    expect(released, isFalse);
    engines.unlock();
    await _settle();
    expect(released, isTrue);
  });

  // The lock lands somewhere between the unlock and the launch's own
  // continuation; which microtask hop that is depends on the runtime, so every
  // position is tried. No position may start the watchers while locked.
  for (var hops = 0; hops < 8; hops++) {
    test(
      'a lock $hops microtasks after the unlock starts nothing while locked',
      () async {
        var startedWhileLocked = 0;
        var starts = 0;
        late final SessionEngines engines;
        engines = SessionEngines([probe.engine()]);
        final startup = ForegroundWalletStartup(
          initialize: () async => const Ok(null),
          startWatchers: () {
            if (engines.isLocked) startedWhileLocked++;
            starts++;
          },
          engines: engines,
        );
        startup.onLockChanged(true);
        final starting = startup.start();
        await _settle();
        unawaited(
          engines.untilUnlocked().then((_) async {
            for (var i = 0; i < hops; i++) {
              await Future<void>.value();
            }
            startup.onLockChanged(true);
          }),
        );
        startup.onLockChanged(false);
        await _settle();
        expect(startedWhileLocked, 0, reason: 'started while locked');

        startup.onLockChanged(false);
        await starting;
        expect(starts, 1);
      },
    );
  }
}
