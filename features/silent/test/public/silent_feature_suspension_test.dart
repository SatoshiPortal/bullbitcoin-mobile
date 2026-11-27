import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:primitives/primitives.dart';
import 'package:silent/src/data/bwk_sp_account_repository.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/silent_feature.dart';
import 'package:silent/src/watchers/sp_electrum_reconnect_watcher.dart';
import 'package:silent/src/watchers/sp_tip_watcher.dart';

class _Account extends Fake implements BwkSpAccountRepository {
  var depth = 0;
  var disposes = 0;
  final stop = Completer<Result<void, SilentFailure>>();

  @override
  void beginTeardown() => depth++;

  @override
  void endTeardown() {
    if (depth > 0) depth--;
  }

  @override
  bool get teardownInProgress => depth > 0;

  @override
  Future<Result<void, SilentFailure>> dispose() {
    disposes++;
    return stop.future;
  }
}

class _Tip extends Fake implements SpTipWatcher {
  var starts = 0;
  var disposes = 0;

  @override
  void start() => starts++;

  @override
  Future<void> dispose() async => disposes++;
}

class _Reconnect extends Fake implements SpElectrumReconnectWatcher {
  var starts = 0;
  var disposes = 0;

  @override
  void start() => starts++;

  @override
  Future<void> dispose() async => disposes++;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _Account account;
  late _Tip tip;
  late _Reconnect reconnect;
  late SilentFeature feature;

  setUp(() {
    account = _Account();
    tip = _Tip();
    reconnect = _Reconnect();
    final services = GetIt.asNewInstance()
      ..registerSingleton<BwkSpAccountRepository>(account)
      ..registerSingleton<SpTipWatcher>(tip)
      ..registerSingleton<SpElectrumReconnectWatcher>(reconnect);
    feature = SilentFeature.forTesting(services)..startForegroundWatchers();
  });

  test(
    'suspend refuses a new account at once and confirms after the stop',
    () async {
      var confirmed = false;
      final suspending = feature.suspend().whenComplete(() => confirmed = true);
      expect(
        account.teardownInProgress,
        isTrue,
        reason: 'revoked before any await',
      );
      await _settle();
      expect(confirmed, isFalse);
      expect(tip.disposes, 1);
      expect(reconnect.disposes, 1);
      expect(account.disposes, 1);

      account.stop.complete(const Ok(null));
      await suspending;
      expect(confirmed, isTrue);
      expect(
        account.teardownInProgress,
        isTrue,
        reason: 'still closed until resume',
      );
    },
  );

  test('resume reopens once and restarts the watchers it stopped', () async {
    final suspending = feature.suspend();
    account.stop.complete(const Ok(null));
    await suspending;

    feature.resume();
    feature.resume();
    expect(account.teardownInProgress, isFalse);
    expect(tip.starts, 2, reason: 'first start plus one restart');
    expect(reconnect.starts, 2);
  });

  test('resume before the stop is confirmed changes nothing', () async {
    final suspending = feature.suspend();
    feature.resume();
    expect(account.teardownInProgress, isTrue);
    expect(tip.starts, 1);
    account.stop.complete(const Ok(null));
    await suspending;
  });

  test('a stop that fails keeps the account closed and reports it', () async {
    final suspending = feature.suspend();
    account.stop.complete(const Err(SilentSessionBusy('stuck')));
    await expectLater(suspending, throwsStateError);
    feature.resume();
    expect(account.teardownInProgress, isTrue);
  });
}
