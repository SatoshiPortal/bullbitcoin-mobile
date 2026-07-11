import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_wallet_data_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_state.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../sp_cubit_harness.dart';

void main() {
  late SpCubitHarness harness;
  late MockLoadSpWalletDataUsecase loadUsecase;
  late MockWatchSpNotificationsUsecase watchUsecase;
  late MockScanSpWalletUsecase scanUsecase;
  late MockStopSpScanUsecase stopUsecase;
  late SpCubit cubit;
  late StreamController<SpNotification> notifController;

  final fakeBalance = SpBalance(
    confirmedSat: BigInt.from(5000),
    totalUnifiedSat: BigInt.from(5000),
  );

  SpWalletData buildData() => SpWalletData(
    wallet: SpWallet(
      spAddress: 'sp1qtest',
      balance: fakeBalance,
      isScanning: false,
      lastScannedHeight: null,
    ),
    history: <SpPayment>[],
    coins: const [],
    network: SpNetwork.regtest,
    backendOnline: true,
  );

  setUp(() {
    harness = SpCubitHarness();
    loadUsecase = harness.loadUsecase;
    watchUsecase = harness.watchUsecase;
    scanUsecase = harness.scanUsecase;
    stopUsecase = harness.stopUsecase;
    notifController = StreamController<SpNotification>.broadcast();

    when(() => loadUsecase.execute())
        .thenAnswer((_) async => Ok<SpWalletData, SpFailure>(buildData()));
    when(() => watchUsecase.execute()).thenAnswer((_) => notifController.stream);
    when(() => scanUsecase.execute())
        .thenAnswer((_) async => const Ok<void, SpFailure>(null));

    cubit = harness.build();
  });

  tearDown(() async {
    await cubit.close();
    await notifController.close();
  });

  test('ScanStarted notification sets isScanning=true and scan bounds', () async {
    await cubit.load();

    notifController.add(const SpScanStarted(800000, 850000));
    await Future.delayed(Duration.zero);

    expect(cubit.state.isScanning, true);
    expect(cubit.state.scanFrom, 800000);
    expect(cubit.state.scanTo, 850000);
    expect(cubit.state.scanCurrent, 800000);
    expect(cubit.state.scanStartTime, isNotNull);
  });

  test('ScanReceiveProgress updates scanCurrent/scanTo, phase=receive', () async {
    await cubit.load();

    notifController.add(const SpScanStarted(800000, 850000));
    await Future.delayed(Duration.zero);

    notifController
        .add(const SpScanReceiveProgress(810000, 850000));
    await Future.delayed(Duration.zero);

    expect(cubit.state.scanCurrent, 810000);
    expect(cubit.state.scanTo, 850000);
    expect(cubit.state.scanPhase, SpScanPhase.receive);
    expect(cubit.state.isScanning, true);
  });

  test('ScanSpendProgress switches to step 2 and rebases the bar', () async {
    await cubit.load();

    notifController.add(const SpScanStarted(800000, 850000));
    await Future.delayed(Duration.zero);
    notifController
        .add(const SpScanReceiveProgress(850000, 850000));
    await Future.delayed(Duration.zero);

    // First spend update: phase flips, scanFrom rebases to the spend start so
    // progress restarts near 0 (not negative against the receive baseline).
    notifController
        .add(const SpScanSpendProgress(800000, 850000));
    await Future.delayed(Duration.zero);

    expect(cubit.state.scanPhase, SpScanPhase.spend);
    expect(cubit.state.scanFrom, 800000);
    expect(cubit.state.scanCurrent, 800000);
    expect(cubit.state.scanTo, 850000);
    expect(cubit.state.scanProgress, 0.0);

    notifController
        .add(const SpScanSpendProgress(825000, 850000));
    await Future.delayed(Duration.zero);
    expect(cubit.state.scanProgress, closeTo(0.5, 0.001));
  });

  test('ScanCompleted notification sets isScanning=false and reloads data', () async {
    await cubit.load();
    clearInteractions(loadUsecase);

    notifController.add(const SpScanStarted(800000, 850000));
    await Future.delayed(Duration.zero);

    notifController.add(const SpScanCompleted());
    await Future.delayed(Duration.zero);

    expect(cubit.state.isScanning, false);
    // Total scan duration is captured for the post-scan view.
    expect(cubit.state.scanLastDurationSecs, isNotNull);
    // The one-shot scan runs on a background thread, so ScanCompleted is the
    // done signal that drives the wallet-data reload.
    verify(() => loadUsecase.execute()).called(1);
  });

  test('ScanStopped notification sets isScanning=false and reloads data', () async {
    await cubit.load();
    clearInteractions(loadUsecase);

    notifController.add(const SpScanStarted(800000, 850000));
    await Future.delayed(Duration.zero);

    notifController.add(const SpScanStopped());
    await Future.delayed(Duration.zero);

    expect(cubit.state.isScanning, false);
    // Reload so lastScannedHeight reflects where the scan stopped (the next
    // scan resumes from there).
    verify(() => loadUsecase.execute()).called(1);
  });

  test('ScanFailed notification sets isScanning=false and sets error', () async {
    await cubit.load();

    notifController.add(const SpScanFailed('network error'));
    await Future.delayed(Duration.zero);

    expect(cubit.state.isScanning, false);
    expect(cubit.state.error, isA<SpUnexpected>());
    expect(
      (cubit.state.error! as SpUnexpected).logMessage,
      contains('network error'),
    );
  });

  group('no auto-scan on init', () {
    test('SpCubit.load() does not trigger scan', () async {
      await cubit.load();
      await Future.delayed(Duration.zero);

      verifyNever(() => scanUsecase.execute());
    });

    test('Electrum balance push does not trigger scan', () async {
      await cubit.load();

      notifController.add(
        SpElectrumTx(
          kind: SpCoinSource.segwit,
          txid: 'aabbcc',
          amountSat: BigInt.from(1000),
        ),
      );
      await Future.delayed(Duration.zero);

      verifyNever(() => scanUsecase.execute());
    });
  });

  test('coin notification during scan defers reload to ScanCompleted', () async {
    await cubit.load();
    notifController.add(const SpScanStarted(1, 10));
    await Future.delayed(Duration.zero);

    // Ignore the initial load() call; assert only what happens during scan.
    clearInteractions(loadUsecase);

    notifController.add(
      SpNewOutput('o:0', BigInt.from(1)),
    );
    await Future.delayed(Duration.zero);
    // Still scanning: defer the reload (avoid churn during the background scan).
    verifyNever(() => loadUsecase.execute());

    notifController.add(const SpScanCompleted());
    await Future.delayed(Duration.zero);
    // ScanCompleted reloads exactly once.
    verify(() => loadUsecase.execute()).called(1);
  });

  test('scan() invokes ScanSpWalletUsecase.execute exactly once per call', () async {
    await cubit.load();

    await cubit.scan();
    verify(() => scanUsecase.execute()).called(1);

    await cubit.scan();
    verify(() => scanUsecase.execute()).called(1);
  });

  test('scan() only goes through ScanSpWalletUsecase', () async {
    // scan() must only go through ScanSpWalletUsecase, never directly to FFI.
    await cubit.load();
    await cubit.scan();

    verify(() => scanUsecase.execute()).called(1);
  });

  test('scan(startHeight) forwards the chosen height to the usecase', () async {
    when(
      () => scanUsecase.execute(startHeight: any(named: 'startHeight')),
    ).thenAnswer((_) async => const Ok<void, SpFailure>(null));
    await cubit.load();

    await cubit.scan(startHeight: 800000);

    verify(() => scanUsecase.execute(startHeight: 800000)).called(1);
  });

  test('scan() sets error and leaves isScanning false when execute throws',
      () async {
    when(() => scanUsecase.execute()).thenAnswer(
      (_) async =>
          const Err<void, SpFailure>(SpUnexpected('scan start failed')),
    );
    await cubit.load();

    await cubit.scan();

    expect(cubit.state.isScanning, false);
    expect(cubit.state.error, isA<SpUnexpected>());
    expect(
      (cubit.state.error! as SpUnexpected).logMessage,
      contains('scan start failed'),
    );
  });

  test('stopScan() invokes StopSpScanUsecase.execute', () async {
    when(() => stopUsecase.execute()).thenAnswer((_) async {});
    await cubit.load();

    await cubit.stopScan();

    verify(() => stopUsecase.execute()).called(1);
  });

  test('scanProgress getter returns 0.0 when scan bounds are null', () {
    expect(cubit.state.scanProgress, 0.0);
  });

  test('scanProgress getter returns correct fraction', () async {
    await cubit.load();

    notifController.add(const SpScanStarted(0, 100));
    await Future.delayed(Duration.zero);

    notifController
        .add(const SpScanReceiveProgress(50, 100));
    await Future.delayed(Duration.zero);

    expect(cubit.state.scanProgress, closeTo(0.5, 0.001));
  });

  group('async edge cases', () {
    test('two synchronous scan() taps invoke the usecase once (double-tap '
        'guard, T1.4)', () async {
      // Hold the first scan open so the second tap lands inside the window
      // before ScanStarted would flip state.isScanning.
      final gate = Completer<Result<void, SpFailure>>();
      when(() => scanUsecase.execute()).thenAnswer((_) => gate.future);
      await cubit.load();

      final first = cubit.scan();
      final second = cubit.scan();
      gate.complete(const Ok(null));
      await Future.wait([first, second]);

      verify(() => scanUsecase.execute()).called(1);
    });

    test('a scanner-already-running error does not clear isScanning (T1.4)',
        () async {
      // The scan really starts (ScanStarted sets isScanning=true) while the
      // execute future is still pending, then reports busy. The catch must not
      // flip isScanning off and wedge the Stop button.
      when(() => scanUsecase.execute()).thenAnswer((_) async {
        notifController.add(const SpScanStarted(1, 10));
        await Future.delayed(Duration.zero);
        return const Err<void, SpFailure>(
          SpScanBusy('scanner already running'),
        );
      });
      await cubit.load();

      await cubit.scan();
      await Future.delayed(Duration.zero);

      expect(cubit.state.isScanning, true);
      expect(cubit.state.error, isNotNull);
    });

    test('a non-busy scan error still clears isScanning (T1.4 contrast)',
        () async {
      when(() => scanUsecase.execute()).thenAnswer((_) async {
        notifController.add(const SpScanStarted(1, 10));
        await Future.delayed(Duration.zero);
        return const Err<void, SpFailure>(
          SpUnexpected('backend unreachable'),
        );
      });
      await cubit.load();

      await cubit.scan();
      await Future.delayed(Duration.zero);

      expect(cubit.state.isScanning, false);
      expect(cubit.state.error, isNotNull);
    });

    test('stopScan() is idempotent across repeated calls', () async {
      when(() => stopUsecase.execute()).thenAnswer((_) async {});
      await cubit.load();

      await cubit.stopScan();
      await cubit.stopScan();

      verify(() => stopUsecase.execute()).called(2);
      expect(cubit.state.error, isNull);
    });

    test('stopScan() swallows a usecase error (no throw, no error state)',
        () async {
      when(() => stopUsecase.execute()).thenThrow(StateError('stop failed'));
      await cubit.load();

      // Must not throw; stopScan is best-effort (the scan tears down async).
      await cubit.stopScan();

      expect(cubit.state.error, isNull);
    });

    test('a notification arriving after close() does not throw or emit',
        () async {
      await cubit.load();
      final emitted = <Object?>[];
      final sub = cubit.stream.listen(emitted.add);

      await cubit.close();
      // Late notification on the still-open controller must be ignored.
      notifController.add(const SpScanStarted(1, 2));
      await Future.delayed(Duration.zero);

      await sub.cancel();
      expect(emitted, isEmpty);
    });

    test('self-heals when its notification stream closes: re-subscribes via '
        'load() (the #2 session-recycle regression)', () async {
      await cubit.load();

      // After the session is recycled, watching yields a fresh (open) stream;
      // mirror the real adapter, which establishes a new broadcast stream for
      // the new session. Left open so re-subscription does not loop.
      final freshController = StreamController<SpNotification>.broadcast();
      when(
        () => watchUsecase.execute(),
      ).thenAnswer((_) => freshController.stream);

      // Simulate the singleton session being disposed out from under the cubit
      // (e.g. a wallet-side full refresh after a network change): its stream
      // completes.
      await notifController.close();
      await Future.delayed(Duration.zero);

      // The cubit must have re-established by reloading + re-subscribing rather
      // than leaving a dead screen: load() ran on entry and again on self-heal,
      // and notifications were watched on each (verify counts cumulatively as
      // these methods are verified only here).
      verify(() => loadUsecase.execute()).called(greaterThanOrEqualTo(2));
      verify(() => watchUsecase.execute()).called(greaterThanOrEqualTo(2));
    });
  });
}
