import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/read_wallet_usecase.dart';
import 'package:transaction_sync/read.dart';
import 'package:transaction_sync/transaction_sync.dart'
    show
        SyncReason,
        TransactionSyncBusyFailure,
        TransactionSyncConnectionFailure;
import 'package:bb_mobile/features/wallet/domain/wallet_discovery_failure.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure_log_code.dart';
import 'dart:async';
import 'dart:io';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';

import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/core/sync/sync_kind.dart';
import 'package:bb_mobile/core/sync/sync_trigger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockReadWallet extends Mock implements ReadWalletUsecase {}

class _MockGetWallets extends Mock implements GetWalletsUsecase {}

class _MockSyncWallet extends Mock implements SyncWalletUsecase {}

class _Wallet extends Mock implements Wallet {}

class _MockSyncSwaps extends Mock {
  Future<void> call();
}

final class _Reporter implements LoggerReporter {
  final List<String?> errors = [];

  @override
  void reportError({
    String? message,
    required Object exception,
    required StackTrace stackTrace,
    required ReportCategory category,
  }) => errors.add(message);

  @override
  Future<void> reportShout({
    required String message,
    Object? exception,
    StackTrace? stackTrace,
    ReportCategory? category,
  }) async {}
}

void main() {
  registerFallbackValue(SyncReason.auto);
  // SyncCoordinator's constructor reads WidgetsBinding.instance and attaches
  // an AppLifecycleListener, so the binding must exist.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockReadWallet readWallet;
  late _MockGetWallets getWallets;
  late _MockSyncWallet syncWallet;
  late _MockSyncSwaps syncSwaps;
  late SyncCoordinator coordinator;
  late Future<void> Function() spCallback;
  var revisionReads = 0;
  var network = Environment.mainnet;

  setUp(() {
    readWallet = _MockReadWallet();
    getWallets = _MockGetWallets();
    syncWallet = _MockSyncWallet();
    syncSwaps = _MockSyncSwaps();
    when(syncSwaps.call).thenAnswer((_) async {});
    spCallback = () async {};
    revisionReads = 0;
    network = Environment.mainnet;
    coordinator = SyncCoordinator(
      readWalletUsecase: readWallet,
      readNetwork: () async => network,
      getWalletsUsecase: getWallets,
      syncWalletUsecase: syncWallet,
      syncSwaps: syncSwaps.call,
      // Deferred so a test can swap the behaviour after construction, the way
      // the composition root's lazy closure resolves the facade at call time.
      syncSp: () => spCallback(),
      refreshRevisions: () async {
        revisionReads++;
      },
    );
  });

  tearDown(() => coordinator.dispose());

  // Each kind's work is gated behind a Completer so the test controls exactly
  // when bitcoin / liquid / sp finish. The wallet list is empty, so no real
  // Wallet needs constructing — the gate alone paces the drain.
  ({Completer<void> bitcoin, Completer<void> liquid, Completer<void> sp})
  wireGates() {
    final bitcoin = Completer<void>();
    final liquid = Completer<void>();
    final sp = Completer<void>();
    when(() => getWallets.execute(onlyBitcoin: true)).thenAnswer((_) async {
      await bitcoin.future;
      return const Ok<List<Wallet>, WalletFailure>([]);
    });
    when(() => getWallets.execute(onlyLiquid: true)).thenAnswer((_) async {
      await liquid.future;
      return const Ok<List<Wallet>, WalletFailure>([]);
    });
    spCallback = () async {
      await sp.future;
    };
    return (bitcoin: bitcoin, liquid: liquid, sp: sp);
  }

  test('one activity interval covers all kinds and none for a no-op', () async {
    final activity = <bool>[];
    final subscription = coordinator.syncPassActivity.listen(activity.add);
    addTearDown(subscription.cancel);
    final gates = wireGates();
    final pass = coordinator.sync();
    await pumpEventQueue();
    expect(activity, [true]);
    gates.bitcoin.complete();
    await pumpEventQueue();
    expect(activity, [true]);
    gates.liquid.complete();
    await pumpEventQueue();
    expect(activity, [true]);
    gates.sp.complete();
    await pass;
    expect(activity, [true, false]);
    await coordinator.sync();
    expect(activity, [true, false]);
  });

  test('pull refresh and automatic sync both use revealed scripts', () async {
    final wallet = _Wallet();
    when(
      () => getWallets.execute(onlyBitcoin: true),
    ).thenAnswer((_) async => Ok([wallet]));
    when(
      () => syncWallet.execute(
        wallet,
        discover: any(named: 'discover'),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) async {});
    await coordinator.sync(only: {SyncKind.bitcoin});
    verify(
      () => syncWallet.execute(
        wallet,
        discover: false,
        reason: any(named: 'reason'),
      ),
    ).called(1);
    await coordinator.sync(only: {SyncKind.bitcoin}, trigger: SyncTrigger.user);
    verify(
      () => syncWallet.execute(
        wallet,
        discover: false,
        reason: any(named: 'reason'),
      ),
    ).called(1);
  });

  test(
    'pull joins an in-flight routine pass without adding discovery',
    () async {
      final wallet = _Wallet();
      final gate = Completer<void>();
      when(
        () => getWallets.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => Ok([wallet]));
      when(
        () => syncWallet.execute(
          wallet,
          discover: false,
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) => gate.future);
      final routine = coordinator.sync(only: {SyncKind.bitcoin});
      await pumpEventQueue();
      var done = false;
      final pull = coordinator
          .sync(only: {SyncKind.bitcoin}, trigger: SyncTrigger.user)
          .then((_) => done = true);
      await pumpEventQueue();
      expect(done, isFalse);
      gate.complete();
      await Future.wait([routine, pull]);
      verify(
        () => syncWallet.execute(
          wallet,
          discover: false,
          reason: any(named: 'reason'),
        ),
      ).called(1);
      verifyNever(
        () => syncWallet.execute(
          wallet,
          discover: true,
          reason: any(named: 'reason'),
        ),
      );
    },
  );

  _Wallet manualWallet(String id, {bool liquid = false}) {
    final wallet = _Wallet();
    when(() => wallet.id).thenReturn(id);
    when(
      () => wallet.network,
    ).thenReturn(liquid ? Network.liquidMainnet : Network.bitcoinMainnet);
    when(() => wallet.isBitcoin).thenReturn(!liquid);
    when(() => wallet.isLiquid).thenReturn(liquid);
    return wallet;
  }

  test(
    'Receive polling targets one wallet with auto provenance and no throttle',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'receive-poll-logs-',
      );
      final reporter = _Reporter();
      log = Logger.replace(directory: directory, reporter: reporter);
      addTearDown(() async {
        await log.flush();
        directory.deleteSync(recursive: true);
      });
      final a = manualWallet('a');
      final b = manualWallet('b');
      when(() => readWallet.execute('a')).thenAnswer((_) async => Ok(a));
      when(() => getWallets.execute()).thenAnswer((_) async => Ok([a, b]));
      when(
        () => getWallets.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => Ok([a]));
      when(
        () => syncWallet.execute(
          a,
          discover: false,
          allowInitialScan: any(named: 'allowInitialScan'),
          reason: SyncReason.auto,
        ),
      ).thenAnswer((_) async {});
      // A just-completed global pass must not swallow the next periodic tick.
      await coordinator.sync(only: {SyncKind.bitcoin});
      await coordinator.pollWallet('a', isActive: () => true);
      await coordinator.pollWallet('a', isActive: () => true);
      verify(
        () => syncWallet.execute(
          a,
          discover: false,
          allowInitialScan: true,
          reason: SyncReason.auto,
        ),
      ).called(1);
      // Global sync keeps bootstrap; both Receive ticks explicitly reject it.
      verify(
        () => syncWallet.execute(
          a,
          discover: false,
          allowInitialScan: false,
          reason: SyncReason.auto,
        ),
      ).called(2);
      verifyNever(
        () => syncWallet.execute(
          b,
          discover: any(named: 'discover'),
          allowInitialScan: any(named: 'allowInitialScan'),
          reason: any(named: 'reason'),
        ),
      );
      when(
        () => syncWallet.execute(
          a,
          discover: false,
          allowInitialScan: any(named: 'allowInitialScan'),
          reason: SyncReason.auto,
        ),
      ).thenThrow(const WalletSnapshotException(TransactionSyncBusyFailure()));
      await coordinator.pollWallet('a', isActive: () => true);
      final lines = (await log.readLogs()).join();
      expect(
        lines,
        contains(
          'Sync pass finished kind=bitcoin reason=auto outcome=settled wallets=1',
        ),
      );
      expect(
        lines,
        contains('reason=auto outcome=busy wallets=1 category=busy'),
      );
      expect(lines, isNot(contains('discovery')));
      expect(reporter.errors, isEmpty);
    },
  );

  for (final cancel in ['never', 'beforeJoin', 'afterJoin']) {
    test('Receive waits for covered passes (cancel=$cancel)', () async {
      final a = manualWallet('a');
      final liquid = manualWallet('liquid', liquid: true);
      when(() => readWallet.execute('a')).thenAnswer((_) async => Ok(a));
      when(
        () => readWallet.execute('liquid'),
      ).thenAnswer((_) async => Ok(liquid));
      when(() => getWallets.execute()).thenAnswer((_) async => Ok([a, liquid]));
      when(
        () => getWallets.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => Ok([a]));
      final held = Completer<void>();
      when(
        () => syncWallet.execute(
          a,
          discover: false,
          allowInitialScan: any(named: 'allowInitialScan'),
          reason: SyncReason.auto,
        ),
      ).thenAnswer((_) => held.future);
      when(
        () => syncWallet.execute(
          liquid,
          discover: false,
          allowInitialScan: any(named: 'allowInitialScan'),
          reason: SyncReason.auto,
        ),
      ).thenAnswer((_) async {});
      final global = coordinator.sync(only: {SyncKind.bitcoin});
      await Future<void>.delayed(Duration.zero);
      var runningEnded = false;
      final running = coordinator
          .pollWallet('a', isActive: () => true)
          .then((_) => runningEnded = true);
      var active = true;
      final queued = coordinator.pollWallet('liquid', isActive: () => active);
      await Future<void>.delayed(Duration.zero);
      if (cancel == 'beforeJoin') active = false;
      var joinedEnded = false;
      final joined = coordinator
          .pollWallet('liquid', isActive: () => true)
          .then((_) => joinedEnded = true);
      verifyNever(
        () => syncWallet.execute(
          liquid,
          discover: false,
          allowInitialScan: any(named: 'allowInitialScan'),
          reason: SyncReason.auto,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(runningEnded, isFalse);
      expect(joinedEnded, isFalse);
      if (cancel == 'afterJoin') active = false;
      held.complete();
      await Future.wait([global, queued, running, joined]);
      expect(runningEnded, isTrue);
      expect(joinedEnded, isTrue);
      verify(
        () => syncWallet.execute(
          a,
          discover: false,
          allowInitialScan: any(named: 'allowInitialScan'),
          reason: SyncReason.auto,
        ),
      ).called(1);
      verify(
        () => syncWallet.execute(
          liquid,
          discover: false,
          allowInitialScan: any(named: 'allowInitialScan'),
          reason: SyncReason.auto,
        ),
      ).called(1);
      await coordinator.pollWallet('liquid', isActive: () => true);
      verify(
        () => syncWallet.execute(
          liquid,
          discover: false,
          allowInitialScan: any(named: 'allowInitialScan'),
          reason: SyncReason.auto,
        ),
      ).called(1);
    });
  }

  test(
    'Receive polling rechecks cancellation after asynchronous wallet admission',
    () async {
      final a = manualWallet('a');
      final read = Completer<Result<Wallet, WalletFailure>>();
      var active = true;
      when(() => readWallet.execute('a')).thenAnswer((_) => read.future);
      final poll = coordinator.pollWallet('a', isActive: () => active);
      active = false;
      read.complete(Ok(a));
      await poll;
      verifyZeroInteractions(syncWallet);
      verifyZeroInteractions(getWallets);
    },
  );

  test(
    'Receive polling awaits a running targeted pass and rejects an inactive network',
    () async {
      final a = manualWallet('a');
      when(() => readWallet.execute('a')).thenAnswer((_) async => Ok(a));
      final held = Completer<void>();
      when(
        () => syncWallet.execute(
          a,
          discover: false,
          allowInitialScan: any(named: 'allowInitialScan'),
          reason: SyncReason.auto,
        ),
      ).thenAnswer((_) => held.future);
      final first = coordinator.pollWallet('a', isActive: () => true);
      await Future<void>.delayed(Duration.zero);
      var joinedEnded = false;
      final joined = coordinator
          .pollWallet('a', isActive: () => true)
          .then((_) => joinedEnded = true);
      await Future<void>.delayed(Duration.zero);
      expect(joinedEnded, isFalse);
      verify(
        () => syncWallet.execute(
          a,
          discover: false,
          allowInitialScan: any(named: 'allowInitialScan'),
          reason: SyncReason.auto,
        ),
      ).called(1);
      held.complete();
      await Future.wait([first, joined]);
      expect(joinedEnded, isTrue);
      network = Environment.testnet;
      await coordinator.pollWallet('a', isActive: () => true);
      verifyNever(
        () => syncWallet.execute(
          a,
          discover: false,
          allowInitialScan: any(named: 'allowInitialScan'),
          reason: SyncReason.auto,
        ),
      );
      verifyZeroInteractions(getWallets);
    },
  );

  test(
    'pass summary preserves the native connection failure category',
    () async {
      final directory = Directory.systemTemp.createTempSync('connection-sync-');
      log = Logger.replace(directory: directory, reporter: _Reporter());
      addTearDown(() async {
        await log.flush();
        directory.deleteSync(recursive: true);
      });
      final wallet = manualWallet('connection-wallet');
      when(
        () => getWallets.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => Ok([wallet]));
      when(
        () => syncWallet.execute(
          wallet,
          discover: any(named: 'discover'),
          reason: any(named: 'reason'),
        ),
      ).thenThrow(
        const WalletSnapshotException(TransactionSyncConnectionFailure()),
      );
      await expectLater(
        coordinator.sync(only: {SyncKind.bitcoin}),
        throwsA(isA<SyncCoordinatorException>()),
      );
      expect(
        (await log.readLogs()).join(),
        contains('outcome=failed wallets=1 category=connection'),
      );
    },
  );

  test(
    'busy discovery fails and routine busy does not throttle a retry',
    () async {
      final directory = Directory.systemTemp.createTempSync('busy-sync-logs-');
      log = Logger.replace(directory: directory, reporter: _Reporter());
      addTearDown(() async {
        await log.flush();
        directory.deleteSync(recursive: true);
      });
      final wallet = manualWallet('busy-wallet');
      when(() => getWallets.execute()).thenAnswer((_) async => Ok([wallet]));
      when(
        () => getWallets.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => Ok([wallet]));
      when(
        () => syncWallet.execute(
          wallet,
          discover: any(named: 'discover'),
          reason: any(named: 'reason'),
        ),
      ).thenThrow(const WalletSnapshotException(TransactionSyncBusyFailure()));
      expect(
        await coordinator.discoverWallet(wallet.id),
        isA<Err<void, WalletDiscoveryFailure>>(),
      );
      await expectLater(
        coordinator.sync(only: {SyncKind.bitcoin}),
        throwsA(isA<SyncCoordinatorException>()),
      );
      final lines = (await log.readLogs()).join();
      expect(
        lines,
        contains('Wallet discovery finished reason=manual outcome=busy'),
      );
      expect(lines, contains('outcome=busy wallets=1 category=busy'));
      expect(lines, isNot(contains('outcome=settled')));
      when(
        () => syncWallet.execute(
          wallet,
          discover: false,
          reason: SyncReason.auto,
        ),
      ).thenAnswer((_) async {});
      await coordinator.sync(only: {SyncKind.bitcoin});
      verify(() => getWallets.execute(onlyBitcoin: true)).called(2);
    },
  );

  for (final failRoutine in [false, true]) {
    test(
      'targeted discovery survives routine failure=$failRoutine and stays serialized',
      () async {
        final activity = <bool>[];
        final subscription = coordinator.syncPassActivity.listen(activity.add);
        addTearDown(subscription.cancel);
        final a = manualWallet('a');
        final b = manualWallet('b');
        final routineGate = Completer<void>();
        final manualGate = Completer<void>();
        when(() => getWallets.execute()).thenAnswer((_) async => Ok([a, b]));
        when(
          () => getWallets.execute(onlyBitcoin: true),
        ).thenAnswer((_) async => Ok([a]));
        when(
          () => syncWallet.execute(
            a,
            discover: false,
            reason: any(named: 'reason'),
          ),
        ).thenAnswer((_) => routineGate.future);
        when(
          () =>
              syncWallet.execute(a, discover: true, reason: SyncReason.manual),
        ).thenAnswer((_) => manualGate.future);
        final routine = coordinator.sync(only: {SyncKind.bitcoin});
        final settledRoutine = failRoutine
            ? expectLater(routine, throwsA(isA<SyncCoordinatorException>()))
            : routine;
        await pumpEventQueue();
        var done = false;
        final manual = coordinator.discoverWallet('a').then((result) {
          expect(result, isA<Ok<void, WalletDiscoveryFailure>>());
          done = true;
        });
        final duplicate = coordinator.discoverWallet('a');
        await pumpEventQueue();
        verifyNever(
          () => syncWallet.execute(
            a,
            discover: true,
            reason: any(named: 'reason'),
          ),
        );
        if (failRoutine) {
          routineGate.completeError(Exception('routine'));
        } else {
          routineGate.complete();
        }
        await settledRoutine;
        await pumpEventQueue();
        expect(done, isFalse);
        expect(activity, [true]);
        expect(coordinator.isSyncPassActive, isTrue);
        verify(
          () =>
              syncWallet.execute(a, discover: true, reason: SyncReason.manual),
        ).called(1);
        verifyNever(
          () => syncWallet.execute(
            b,
            discover: any(named: 'discover'),
            reason: any(named: 'reason'),
          ),
        );
        manualGate.complete();
        await Future.wait([manual, duplicate]);
        expect(done, isTrue);
        expect(activity, [true, false]);
        expect(coordinator.isSyncPassActive, isFalse);
      },
    );
  }

  test(
    'manual liquid uses normal sync and does not throttle other wallets',
    () async {
      final wallet = manualWallet('liquid', liquid: true);
      when(() => getWallets.execute()).thenAnswer((_) async => Ok([wallet]));
      when(
        () => getWallets.execute(onlyLiquid: true),
      ).thenAnswer((_) async => Ok([wallet]));
      when(
        () => syncWallet.execute(
          wallet,
          discover: false,
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async {});
      expect(
        await coordinator.discoverWallet('liquid'),
        isA<Ok<void, WalletDiscoveryFailure>>(),
      );
      await coordinator.sync(only: {SyncKind.liquid});
      verify(
        () => syncWallet.execute(
          wallet,
          discover: false,
          reason: SyncReason.manual,
        ),
      ).called(1);
      verify(
        () => syncWallet.execute(
          wallet,
          discover: false,
          reason: SyncReason.auto,
        ),
      ).called(1);
      verifyNever(
        () => syncWallet.execute(
          wallet,
          discover: true,
          reason: any(named: 'reason'),
        ),
      );
    },
  );

  test(
    'queued discovery rechecks the active environment and wallet existence',
    () async {
      final a = manualWallet('a');
      final blocker = Completer<void>();
      var wallets = <Wallet>[a];
      when(() => getWallets.execute()).thenAnswer((_) async => Ok(wallets));
      when(() => getWallets.execute(onlyBitcoin: true)).thenAnswer((_) async {
        await blocker.future;
        return const Ok(<Wallet>[]);
      });
      final routine = coordinator.sync(only: {SyncKind.bitcoin});
      await pumpEventQueue();
      final manual = coordinator.discoverWallet('a');
      await pumpEventQueue();
      wallets = [];
      blocker.complete();
      await routine;
      expect(
        await manual,
        isA<Err<void, WalletDiscoveryFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<WalletDiscoveryUnavailableFailure>(),
        ),
      );
      verifyNever(
        () => syncWallet.execute(
          a,
          discover: any(named: 'discover'),
          reason: any(named: 'reason'),
        ),
      );
    },
  );

  test(
    'manual failure is typed and its start and finish are persisted once',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'manual-sync-logs-',
      );
      log = Logger.replace(directory: directory, reporter: _Reporter());
      addTearDown(() async {
        await log.flush();
        await directory.delete(recursive: true);
      });
      final a = manualWallet('private-wallet-id');
      when(() => getWallets.execute()).thenAnswer((_) async => Ok([a]));
      when(
        () => syncWallet.execute(a, discover: true, reason: SyncReason.manual),
      ).thenThrow(Exception('sync'));
      expect(
        await coordinator.discoverWallet(a.id),
        isA<Err<void, WalletDiscoveryFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<WalletDiscoverySyncFailure>(),
        ),
      );
      verify(
        () => syncWallet.execute(a, discover: true, reason: SyncReason.manual),
      ).called(1);
      final lines = await log.readLogs();
      expect(
        lines.where((line) => line.contains('discovery started reason=manual')),
        hasLength(1),
      );
      expect(
        lines.where(
          (line) =>
              line.contains('discovery finished reason=manual outcome=failed'),
        ),
        hasLength(1),
      );
      expect(lines.join(), isNot(contains(a.id)));
    },
  );

  test('sync resolves only after every requested kind has settled', () async {
    final gates = wireGates();

    var done = false;
    final future = coordinator
        .sync(trigger: SyncTrigger.automatic)
        .then((_) => done = true);

    await pumpEventQueue();
    expect(done, isFalse, reason: 'bitcoin still in flight');

    gates.bitcoin.complete();
    await pumpEventQueue();
    expect(done, isFalse, reason: 'liquid still in flight');

    gates.liquid.complete();
    await pumpEventQueue();
    expect(done, isFalse, reason: 'sp still in flight');

    gates.sp.complete();
    await future;
    expect(done, isTrue);
  });

  test(
    'a sync awaits the kinds IT requested even when it joins an in-flight '
    'drain that is about to finish (regression: spinner stopped after bitcoin)',
    () async {
      final gates = wireGates();

      // First caller drains bitcoin only.
      var firstDone = false;
      final first = coordinator
          .sync(only: {SyncKind.bitcoin})
          .then((_) => firstDone = true);
      await pumpEventQueue(); // bitcoin now running, gated.

      // Second caller joins while bitcoin is in flight and adds liquid.
      var secondDone = false;
      final second = coordinator
          .sync(only: {SyncKind.liquid})
          .then((_) => secondDone = true);

      gates.bitcoin.complete();
      await first;
      expect(firstDone, isTrue, reason: 'first only asked for bitcoin');
      expect(secondDone, isFalse, reason: 'liquid still pending');

      gates.liquid.complete();
      await second;
      expect(secondDone, isTrue);
    },
  );

  test('automatic re-sync within the throttle window is skipped; '
      'a user sync bypasses it', () async {
    // No gating: each kind completes immediately so _lastSuccessAt is set.
    when(
      () => getWallets.execute(onlyBitcoin: true),
    ).thenAnswer((_) async => Ok(<Wallet>[]));
    when(
      () => getWallets.execute(onlyLiquid: true),
    ).thenAnswer((_) async => Ok(<Wallet>[]));
    await coordinator.sync(trigger: SyncTrigger.automatic);
    // Immediately again (well within the 2s window); every kind is throttled.
    await coordinator.sync(trigger: SyncTrigger.automatic);

    verify(() => getWallets.execute(onlyBitcoin: true)).called(1);
    verify(() => getWallets.execute(onlyLiquid: true)).called(1);
    verifyNever(syncSwaps.call);
    // A user gesture bypasses the throttle and re-runs every kind.
    await coordinator.sync(trigger: SyncTrigger.user);

    verify(() => getWallets.execute(onlyBitcoin: true)).called(1);
    verify(() => getWallets.execute(onlyLiquid: true)).called(1);
    verifyNever(syncSwaps.call);
  });

  test(
    'a failed wallet read fails the round and does not arm the throttle',
    () async {
      // Degrading the failure to an empty list would let the round complete
      // normally, stamping _lastSuccessAt — so the sync would be reported as
      // successful AND the throttle would then suppress the retry that would
      // recover from a transient read failure.
      when(() => getWallets.execute(onlyBitcoin: true)).thenAnswer(
        (_) async => const Err<List<Wallet>, WalletFailure>(
          WalletStorageFailure('SqliteException(11): disk image is malformed'),
        ),
      );
      when(
        () => getWallets.execute(onlyLiquid: true),
      ).thenAnswer((_) async => Ok(<Wallet>[]));

      await expectLater(
        coordinator.sync(trigger: SyncTrigger.automatic),
        throwsA(isA<Exception>()),
      );

      // Not throttled away: the next automatic round retries bitcoin.
      await coordinator.sync(trigger: SyncTrigger.automatic).catchError((_) {});

      verify(() => getWallets.execute(onlyBitcoin: true)).called(2);
    },
  );

  test('a general sync does not wait for swap polling', () async {
    final order = <String>[];
    when(() => getWallets.execute(onlyBitcoin: true)).thenAnswer((_) async {
      order.add('bitcoin');
      return const Ok<List<Wallet>, WalletFailure>([]);
    });
    when(() => getWallets.execute(onlyLiquid: true)).thenAnswer((_) async {
      order.add('liquid');
      return const Ok<List<Wallet>, WalletFailure>([]);
    });
    when(syncSwaps.call).thenAnswer((_) async => order.add('swaps'));

    await coordinator.sync(trigger: SyncTrigger.user);

    expect(order, ['bitcoin', 'liquid']);
    verifyNever(syncSwaps.call);
  });

  test('deduplicates concurrent swap syncs', () async {
    final gate = Completer<void>();
    when(syncSwaps.call).thenAnswer((_) => gate.future);

    final first = coordinator.sync(
      only: {SyncKind.swaps},
      trigger: SyncTrigger.user,
    );
    final second = coordinator.sync(
      only: {SyncKind.swaps},
      trigger: SyncTrigger.user,
    );
    await pumpEventQueue();

    verify(syncSwaps.call).called(1);
    gate.complete();
    await Future.wait([first, second]);
  });

  test('does not sync swaps while the app is paused', () async {
    when(
      () => getWallets.execute(onlyBitcoin: true),
    ).thenAnswer((_) async => Ok(<Wallet>[]));
    when(
      () => getWallets.execute(onlyLiquid: true),
    ).thenAnswer((_) async => Ok(<Wallet>[]));
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(state);
    }

    await coordinator.sync(only: {SyncKind.swaps}, trigger: SyncTrigger.user);

    verifyNever(syncSwaps.call);
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(state);
    }
    await pumpEventQueue();
    expect(revisionReads, 1);
  });

  group('SyncKind.sp', () {
    test('sync() invokes the registered syncSp once', () async {
      when(
        () => getWallets.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => Ok(<Wallet>[]));
      when(
        () => getWallets.execute(onlyLiquid: true),
      ).thenAnswer((_) async => Ok(<Wallet>[]));
      when(syncSwaps.call).thenAnswer((_) async {});
      var spCalls = 0;
      spCallback = () async => spCalls++;

      await coordinator.sync(only: {SyncKind.sp}, trigger: SyncTrigger.user);

      expect(spCalls, 1);
    });

    test('a syncSp throw does not sink bitcoin/liquid and '
        'surfaces as the sp failure', () async {
      when(
        () => getWallets.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => Ok(<Wallet>[]));
      when(
        () => getWallets.execute(onlyLiquid: true),
      ).thenAnswer((_) async => Ok(<Wallet>[]));
      when(syncSwaps.call).thenAnswer((_) async {});
      spCallback = () async => throw Exception('sp boom');

      Object? thrown;
      try {
        await coordinator.sync(trigger: SyncTrigger.automatic);
      } catch (e) {
        thrown = e;
      }

      // The other kinds still ran to completion despite sp failing.
      verify(() => getWallets.execute(onlyBitcoin: true)).called(1);
      verify(() => getWallets.execute(onlyLiquid: true)).called(1);
      // sp's failure is reported, not swallowed, and is the only failed kind.
      expect(thrown, isA<SyncCoordinatorException>());
      final failures = (thrown! as SyncCoordinatorException).failures;
      expect(failures.keys, [SyncKind.sp]);
    });

    test('sp is throttled like the others: an automatic re-sync within the '
        'window is skipped; a user sync bypasses it', () async {
      when(
        () => getWallets.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => Ok(<Wallet>[]));
      when(
        () => getWallets.execute(onlyLiquid: true),
      ).thenAnswer((_) async => Ok(<Wallet>[]));
      when(syncSwaps.call).thenAnswer((_) async {});
      var spCalls = 0;
      spCallback = () async => spCalls++;

      await coordinator.sync(trigger: SyncTrigger.automatic);
      await coordinator.sync(trigger: SyncTrigger.automatic);
      expect(spCalls, 1, reason: 'second automatic sp sync is throttled');

      await coordinator.sync(only: {SyncKind.sp}, trigger: SyncTrigger.user);
      expect(spCalls, 2, reason: 'a user sync bypasses the sp throttle');
    });

    test('a user sync leaves sp out unless asked for it', () async {
      when(
        () => getWallets.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => Ok(<Wallet>[]));
      when(
        () => getWallets.execute(onlyLiquid: true),
      ).thenAnswer((_) async => Ok(<Wallet>[]));
      var spCalls = 0;
      spCallback = () async => spCalls++;

      await coordinator.sync(trigger: SyncTrigger.user);

      verify(() => getWallets.execute(onlyBitcoin: true)).called(1);
      verify(() => getWallets.execute(onlyLiquid: true)).called(1);
      expect(spCalls, 0);
    });
  });

  group('failure reporting', () {
    late _Reporter reporter;

    setUp(() async {
      final directory = await Directory.systemTemp.createTemp('sync-logs-');
      addTearDown(() async {
        await log.flush();
        await directory.delete(recursive: true);
      });
      reporter = _Reporter();
      log = Logger.replace(directory: directory, reporter: reporter);
    });

    test(
      'long wallet failure names retain their category in support logs',
      () async {
        const failure = WalletCannotDeleteWithOngoingSwapsFailure();
        log.warning('Wallet operation unavailable category=${failure.logCode}');
        final lines = await log.readLogs();
        expect(lines.join(), contains('category=ongoing_swaps'));
        expect(lines.join(), isNot(contains('[REDACTED]')));
        expect(reporter.errors, isEmpty);
      },
    );

    test(
      'coalesced callers persist one pass and throttling stays silent',
      () async {
        final gate = Completer<List<Wallet>>();
        when(
          () => getWallets.execute(onlyBitcoin: true),
        ).thenAnswer((_) async => Ok(await gate.future));
        final first = coordinator.sync(only: {SyncKind.bitcoin});
        final second = coordinator.sync(only: {SyncKind.bitcoin});
        await Future<void>.delayed(Duration.zero);
        gate.complete([]);
        await Future.wait([first, second]);
        await coordinator.sync(only: {SyncKind.bitcoin});
        final messages = (await log.readLogs())
            .map((line) => line.split('\t')[2])
            .toList();
        expect(
          messages.where((message) => message.startsWith('Sync pass finished')),
          hasLength(1),
        );
        expect(messages.join(), contains('outcome=no_wallets wallets=0'));
        expect(messages.join(), isNot(contains('sync ok')));
        expect(reporter.errors, isEmpty);
      },
    );

    test(
      'queued pull upgrades auto while running auto keeps its reason',
      () async {
        final bitcoin = manualWallet('bitcoin');
        final liquid = manualWallet('liquid', liquid: true);
        final gate = Completer<void>();
        when(
          () => getWallets.execute(onlyBitcoin: true),
        ).thenAnswer((_) async => Ok([bitcoin]));
        when(
          () => getWallets.execute(onlyLiquid: true),
        ).thenAnswer((_) async => Ok([liquid]));
        when(
          () => syncWallet.execute(
            bitcoin,
            discover: false,
            reason: SyncReason.auto,
          ),
        ).thenAnswer((_) => gate.future);
        when(
          () => syncWallet.execute(
            liquid,
            discover: false,
            reason: SyncReason.pull,
          ),
        ).thenAnswer((_) async {});
        final auto = coordinator.sync(
          only: {SyncKind.bitcoin, SyncKind.liquid},
        );
        await pumpEventQueue();
        final pull = coordinator.sync(
          only: {SyncKind.bitcoin, SyncKind.liquid},
          trigger: SyncTrigger.user,
        );
        await pumpEventQueue();
        gate.complete();
        await Future.wait([auto, pull]);
        verify(
          () => syncWallet.execute(
            bitcoin,
            discover: false,
            reason: SyncReason.auto,
          ),
        ).called(1);
        verify(
          () => syncWallet.execute(
            liquid,
            discover: false,
            reason: SyncReason.pull,
          ),
        ).called(1);
        final rows = (await log.readLogs())
            .where((row) => row.contains('Sync pass finished'))
            .toList();
        expect(rows, hasLength(2));
        expect(rows[0], contains('kind=bitcoin reason=auto'));
        expect(rows[1], contains('kind=liquid reason=pull'));
        expect(rows, everyElement(contains('category=none')));
        expect(reporter.errors, isEmpty);
      },
    );

    void walletsRead(WalletFailure failure) {
      when(
        () => getWallets.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => Err<List<Wallet>, WalletFailure>(failure));
      when(
        () => getWallets.execute(onlyLiquid: true),
      ).thenAnswer((_) async => Err<List<Wallet>, WalletFailure>(failure));
    }

    test('no wallet yet still fails the sync but is not reported', () async {
      walletsRead(const NoWalletsFoundFailure());

      await expectLater(
        coordinator.sync(trigger: SyncTrigger.user),
        throwsA(isA<SyncCoordinatorException>()),
      );
      expect(reporter.errors, isEmpty);
    });

    test('a wallet read failure is not reported again by waiters', () async {
      walletsRead(const WalletStorageFailure());

      await expectLater(
        coordinator.sync(trigger: SyncTrigger.user),
        throwsA(isA<SyncCoordinatorException>()),
      );
      expect(reporter.errors, isEmpty);
    });
  });
}
