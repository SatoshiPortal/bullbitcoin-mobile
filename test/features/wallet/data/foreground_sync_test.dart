import 'dart:async';

import 'package:bb_mobile/features/wallet/domain/sync_kind.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/swap/domain/usecases/refresh_order_swaps_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/refresh_pending_order_swaps_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/apply_completed_order_swap_labels_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/schedule_order_swap_refresh_usecase.dart';
import 'package:bb_mobile/features/swap/order_swap_watcher.dart';
import 'package:bb_mobile/features/wallet/data/coordinated_swap_sync.dart';
import 'package:bb_mobile/features/wallet/data/sync_coordinator.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/sync_order_swaps_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/sync_sp_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/wallet_sync_locator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _RefreshPending extends Mock implements RefreshPendingOrderSwapsUsecase {}

class _ApplyLabels extends Mock
    implements ApplyCompletedOrderSwapLabelsUsecase {}

class _Swaps extends Mock implements SwapFacade {}

class _Sp extends Mock implements SpFacade {}

class _GetWallets extends Mock implements GetWalletsUsecase {}

class _SyncWallet extends Mock implements SyncWalletUsecase {}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late _Swaps swaps;
  late _Sp sp;
  late GetIt locator;
  late SyncCoordinator coordinator;

  setUp(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    locator = GetIt.asNewInstance();
    locator.registerSingleton<GetWalletsUsecase>(_GetWallets());
    locator.registerSingleton<SyncWalletUsecase>(_SyncWallet());
    SyncLocator.setupForeground(locator);
    // Resolution before either facade exists must remain safe.
    coordinator = locator<SyncCoordinator>();
    swaps = _Swaps();
    sp = _Sp();
    locator.registerSingleton<SwapFacade>(swaps);
    locator.registerSingleton<SpFacade>(sp);
  });

  tearDown(() async {
    coordinator.dispose();
    await locator.reset();
  });

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
        final outcome = await locator<SyncOrderSwapsUsecase>().execute();
        expect(
          outcome.kind,
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
      final outcome = await locator<SyncOrderSwapsUsecase>().execute();
      expect(outcome.kind, SyncOutcomeKind.rateLimited);
      expect(outcome.failure, isNotNull);
      expect(outcome.retryAfter, retryAfter);
    }
  });

  test(
    'thrown refresh preserves last outcome, including initial null',
    () async {
      final port = locator<SwapSyncPort>();
      when(
        swaps.refreshOrdersWithOutcome,
      ).thenThrow(Exception('private detail'));
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
    final port = locator<SwapSyncPort>();
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
        ScheduleOrderSwapRefreshUsecase(locator<SwapSyncPort>()),
      );
      addTearDown(watcher.dispose);
      await watcher.refresh();
      final attempt = await locator<SwapSyncPort>().request();
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
      final scheduled = locator<SwapSyncPort>().request();
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
      await expectLater(
        CoordinatedSwapSync(coordinator).request(),
        throwsA(same(error)),
      );
    },
  );

  test('SP failure fails the pass without throttling its retry', () async {
    when(
      sp.syncWallet,
    ).thenAnswer((_) async => const Err(SpBackendUnreachable('private')));
    final result = await locator<SyncSpForWalletUsecase>().execute();
    expect(result, isA<Err<void, WalletFailure>>());
    await expectLater(
      coordinator.sync(only: {SyncKind.sp}),
      throwsA(isA<SyncCoordinatorException>()),
    );
    when(sp.syncWallet).thenAnswer((_) async => const Ok(null));
    await coordinator.sync(only: {SyncKind.sp});
    verify(sp.syncWallet).called(3);
  });
}
