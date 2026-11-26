import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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
}
