import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:overview/overview.dart';
import 'package:overview/setup.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:silent/silent.dart';
import 'package:swap_feature/swap_feature.dart';
import 'package:swap_feature/testing.dart';
import 'package:swaps/order_swaps.dart';
import 'package:sync/sync.dart';

class _Inventory extends Mock implements WalletInventory {}

class _Settings extends Mock implements Preferences {}

class _RefreshPending extends Mock implements RefreshPendingOrderSwapsUsecase {}

class _ApplyLabels extends Mock
    implements ApplyCompletedOrderSwapLabelsUsecase {}

class _Swaps extends Mock implements SwapActivity {}

class _Sp extends Mock implements Silent {}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late _Swaps swaps;
  late _Sp sp;
  late OverviewSynchronization foreground;
  late SyncCoordinator<WalletKey, SyncFailure> coordinator;
  late SwapSyncPort port;

  setUp(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final settings = _Settings();
    when(settings.readActiveEnvironment)
        .thenAnswer((_) async => const Ok(Environment.mainnet));
    foreground = OverviewSynchronization.open(
      inventory: _Inventory(),
      readInSession: <T>(Future<T> Function() read) async => Ok(await read()),
      environment: settings,
      catalog: () => throw StateError('Unexpected wallet catalog read'),
      synchronize: (
        _, {
        discover = false,
        allowInitialScan = true,
        reason = SyncReason.auto,
      }) => throw StateError('Unexpected wallet sync'),
      refreshRevisions: () async => const Ok(null),
      swaps: () => swaps,
      silent: () => sp,
    );
    // Resolution before either facade exists must remain safe.
    coordinator = foreground.coordinator;
    port = foreground.swapPolling;
    swaps = _Swaps();
    sp = _Sp();
  });

  tearDown(() => foreground.close());

  for (final count in [0, 1]) {
    test(
      'swap batch with $count pollable orders maps its polling state',
      () async {
        when(swaps.refreshOrdersWithOutcome).thenAnswer(
          (_) async => Ok(
            OrderSwapRefreshBatch(
              pollableOrderCount: count,
              refreshed: [],
              failures: [],
            ),
          ),
        );
        await port.request();
        expect(
          coordinator.lastSwapSyncOutcome?.kind,
          count == 0 ? SyncOutcomeKind.idle : SyncOutcomeKind.active,
        );
      },
    );
  }

  test('embedded and top-level limits preserve retry delay', () async {
    const limit = SwapRateLimitedFailure(retryAfter: Duration(minutes: 2));
    for (final (result, retryAfter)
        in <(Result<OrderSwapRefreshBatch, SwapFailure>, Duration?)>[
          (
            const Ok(
              OrderSwapRefreshBatch(
                pollableOrderCount: 1,
                refreshed: [],
                failures: [limit],
              ),
            ),
            const Duration(minutes: 2),
          ),
          (const Err(limit), const Duration(minutes: 2)),
          (const Err(SwapRateLimitedFailure()), null),
          (const Err(SwapNetworkFailure()), null),
        ]) {
      when(swaps.refreshOrdersWithOutcome).thenAnswer((_) async => result);
      await port.request();
      final outcome = coordinator.lastSwapSyncOutcome;
      expect(outcome?.kind, SyncOutcomeKind.rateLimited);
      expect(outcome?.failure, isNotNull);
      expect(outcome?.retryAfter, retryAfter);
    }
  });

  test(
    'thrown refresh preserves last outcome, including initial null',
    () async {
      when(swaps.refreshOrdersWithOutcome)
          .thenThrow(Exception('private detail'));
      final initial = await port.request();
      expect(initial.lastOutcome, isNull);
      expect(initial.failure, isA<SwapUnexpectedFailure>());
      expect(initial.failure?.logMessage, isNot(contains('private detail')));
      coordinator.lastSwapSyncOutcome = const SyncOutcome.idle();
      final previous = await port.request();
      expect(previous.lastOutcome?.kind, OrderSwapPollingKind.idle);
      expect(previous.failure, isA<SwapUnexpectedFailure>());
    },
  );

  test('gated calls preserve previous polling state', () async {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
    expect((await port.request()).lastOutcome, isNull);
    coordinator.lastSwapSyncOutcome = const SyncOutcome.idle();
    expect((await port.request()).lastOutcome?.kind, OrderSwapPollingKind.idle);
    verifyNever(swaps.refreshOrdersWithOutcome);
  });

  test(
    'watcher goes through the queue once and then respects throttle',
    () async {
      when(swaps.refreshOrdersWithOutcome).thenAnswer(
        (_) async => const Ok(
          OrderSwapRefreshBatch(
            pollableOrderCount: 0,
            refreshed: [],
            failures: [],
          ),
        ),
      );
      final watcher = OrderSwapWatcher(
        ScheduleOrderSwapRefreshUsecase(() => port),
      );
      addTearDown(watcher.dispose);
      await watcher.refresh();
      final attempt = await port.request();
      expect(attempt.lastOutcome?.kind, OrderSwapPollingKind.idle);
      expect(attempt.failure, isNull);
      verify(swaps.refreshOrdersWithOutcome).called(1);
    },
  );

  test(
    'direct and scheduled refresh share the existing singleton guard',
    () async {
      final pending = _RefreshPending();
      final labels = _ApplyLabels();
      final gate = Completer<Result<OrderSwapRefreshBatch, SwapFailure>>();
      when(pending.execute).thenAnswer((_) => gate.future);
      when(labels.execute).thenAnswer((_) async => const Ok(0));
      final refresh = RefreshOrderSwapsUsecase(pending, labels);
      when(swaps.refreshOrdersWithOutcome).thenAnswer((_) => refresh.execute());
      final direct = refresh.execute();
      final scheduled = port.request();
      await Future<void>.delayed(Duration.zero);
      verify(pending.execute).called(1);
      gate.complete(
        const Ok(
          OrderSwapRefreshBatch(
            pollableOrderCount: 0,
            refreshed: [],
            failures: [],
          ),
        ),
      );
      await direct;
      expect((await scheduled).lastOutcome?.kind, OrderSwapPollingKind.idle);
      verify(labels.execute).called(1);
      verify(swaps.refreshOrdersWithOutcome).called(1);
    },
  );

  test(
    'programmer errors wrapped by the queue are not recoverable failures',
    () async {
      final error = StateError('programmer error');
      when(swaps.refreshOrdersWithOutcome).thenThrow(error);
      await expectLater(port.request(), throwsA(same(error)));
    },
  );

  test('SP failure fails the pass without throttling its retry', () async {
    when(
      sp.syncWallet,
    ).thenAnswer((_) async => const Err(SilentBackendUnreachable('private')));
    await expectLater(
      coordinator.sync(only: {SyncKind.sp}),
      throwsA(isA<SyncCoordinatorException>()),
    );
    when(sp.syncWallet).thenAnswer((_) async => const Ok(null));
    await coordinator.sync(only: {SyncKind.sp});
    verify(sp.syncWallet).called(2);
  });
}
