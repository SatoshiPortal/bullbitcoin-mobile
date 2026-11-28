import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:overview/overview.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:silent/silent.dart';

import '../support/overview_home_harness.dart';

final class _Preferences implements AmountDisplayPreferencesReader {
  final Stream<Result<AmountDisplayPreferences, PreferencesFailure>> updates;

  _Preferences(this.updates);

  @override
  Stream<Result<AmountDisplayPreferences, PreferencesFailure>>
  watchDisplayPreferences() => updates;
}

void main() {
  test(
    'amount display masks failures, recovers and cancels its source',
    () async {
      var cancelled = false;
      final updates =
          StreamController<
            Result<AmountDisplayPreferences, PreferencesFailure>
          >(onCancel: () => cancelled = true);
      addTearDown(updates.close);
      const visible = (
        bitcoinUnit: BitcoinUnit.sats,
        hideAmounts: false,
        currencyCode: 'USD',
      );
      final values = <AmountDisplayPreferences?>[];
      final subscription = OverviewAmountDisplay(_Preferences(updates.stream))
          .watch()
          .listen(values.add);
      updates.add(const Ok(visible));
      updates.add(const Err(PreferencesReadFailure()));
      updates.add(const Ok(visible));
      await flushEvents();
      expect(values, [visible, null, visible]);
      await subscription.cancel();
      expect(cancelled, isTrue);
    },
  );

  test('user refresh does not await a blocked swap retry', () async {
    final h = OverviewHomeHarness();
    addTearDown(h.close);
    final retry = Completer<void>();
    when(() => h.swapActivity.retryOngoingSwaps())
        .thenAnswer((_) => retry.future);
    await h.mount();
    h.controller.refreshVisible();
    await flushEvents();
    verifyNever(() => h.swapActivity.retryOngoingSwaps());
    await h.controller.refresh();
    verify(() => h.swapActivity.retryOngoingSwaps()).called(1);
    expect(retry.isCompleted, isFalse);
    retry.complete();
  });

  test('closing Home cancels the amount preferences subscription', () async {
    final h = OverviewHomeHarness();
    addTearDown(h.close);
    var cancelled = false;
    final updates =
        StreamController<Result<AmountDisplayPreferences, PreferencesFailure>>(
          onCancel: () => cancelled = true,
        );
    addTearDown(updates.close);
    final home = OverviewHomeController(
      catalogue: h.source,
      sync: h.sync,
      amountDisplay: OverviewAmountDisplay(_Preferences(updates.stream)),
      ongoingSwaps: h.swaps,
      swapServerCheck: h.swapServer,
      readBackupWarning: () async => null,
      readPhysicalBackup: (_) async => false,
      proxyNeedsAttention: () async => false,
      silentHome: SilentHomeObservation(h.silent),
      syncStarted: h.started.stream,
      syncFinished: h.finished.stream,
      electrumResults: h.electrum.stream,
    );
    await home.close();
    expect(cancelled, isTrue);
  });

  test('waiting for an active refresh never starts a second pass', () async {
    final h = OverviewHomeHarness();
    addTearDown(h.close);
    await h.mount();
    h.sync.autoComplete = false;
    h.controller.refreshVisible();
    await flushEvents();
    var done = false;
    final waiting = h.controller.waitForRefresh().then((_) => done = true);
    await flushEvents();
    expect(done, isFalse);
    expect(h.sync.triggers, [SyncTrigger.automatic]);
    expect(h.sync.pending, 1);
    h.sync.completeNext(HomeSyncOutcome.completed);
    await waiting;
    expect(done, isTrue);
    await h.controller.waitForRefresh();
    expect(h.sync.triggers, [SyncTrigger.automatic]);
  });
}
