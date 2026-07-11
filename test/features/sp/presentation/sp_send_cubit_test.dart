import 'dart:async';

import 'package:bb_mobile/core/utils/logger.dart' hide Logger;
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bb_mobile/features/sp/presentation/sp_send_cubit.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_tx_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging_colorful/logging_colorful.dart';
import 'package:mocktail/mocktail.dart';

import '../sp_cubit_harness.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(<SpRecipient>[]);
    registerFallbackValue(BigInt.zero);
    registerFallbackValue(
      SpTxDraft(
        handle: Object(),
        inputs: const [],
        outputs: const [],
        feeSat: BigInt.zero,
        changeSat: BigInt.zero,
      ),
    );
  });

  late SpSendCubitHarness harness;
  late MockPrepareSpPaymentUsecase prepareUsecase;
  late MockSendSpPaymentUsecase sendUsecase;
  late MockGetSpNetworkUsecase networkUsecase;
  late MockGetSpBalanceUsecase balanceUsecase;
  late SpSendCubit cubit;

  final fakeBalance = SpBalance(
    confirmedSat: BigInt.from(50000),
    totalUnifiedSat: BigInt.from(50000),
  );

  final fakeTxSimulation = SpTxDraft(
    handle: Object(),
    inputs: [],
    outputs: [],
    feeSat: BigInt.from(200),
    changeSat: BigInt.from(44800),
  );

  const fakeTxid =
      'aabbccddeeff0011aabbccddeeff0011aabbccddeeff0011aabbccddeeff0011';

  setUp(() {
    harness = SpSendCubitHarness();
    prepareUsecase = harness.prepareUsecase;
    sendUsecase = harness.sendUsecase;
    networkUsecase = harness.networkUsecase;
    balanceUsecase = harness.balanceUsecase;

    // Mainnet so the sample `sp1…` recipients below match the wallet network
    // (the cubit rejects a wrong-network silent payment address up front).
    when(() => networkUsecase.execute()).thenReturn(SpNetwork.bitcoin);
    when(() => balanceUsecase.execute()).thenReturn(fakeBalance);

    when(
      () => prepareUsecase.execute(
        recipients: any(named: 'recipients'),
        feerateSatVb: any(named: 'feerateSatVb'),
      ),
    ).thenAnswer((_) async => Ok<SpTxDraft, SpFailure>(fakeTxSimulation));

    // The repository logs the txid before returning so it survives an
    // emit-after-close race; mirror that by logging at INFO in the mock.
    when(
      () => sendUsecase.execute(draft: any(named: 'draft')),
    ).thenAnswer((_) async {
      log.info('SP broadcast txid: $fakeTxid');
      return const Ok<String, SpFailure>(fakeTxid);
    });

    cubit = harness.build();
  });

  tearDown(() async {
    await cubit.close();
  });

  group('send-flow validation', () {
    test('previewRecipient rejects a wrong-network silent payment address '
        '(testnet address on a mainnet wallet)', () {
      cubit.previewRecipient('tsp1qexampleaddress');
      expect(
        cubit.state.recipient,
        isNull,
        reason: 'a tsp1 address must not be accepted on a mainnet wallet',
      );
      expect(cubit.state.error, isA<SpAddressNetworkMismatch>());
    });

    test('previewRecipient rejects a mainnet address on a test-network wallet',
        () {
      // Reverse of the case above: an sp1... mainnet address on a testnet
      // wallet must be rejected up front.
      when(() => networkUsecase.execute()).thenReturn(SpNetwork.testnet);
      cubit.previewRecipient('sp1qexampleaddress');
      expect(cubit.state.recipient, isNull);
      expect(cubit.state.error, isA<SpAddressNetworkMismatch>());
    });

    test('previewRecipient accepts a matching-network silent payment address',
        () {
      cubit.previewRecipient('sp1qexampleaddress');
      expect(cubit.state.recipient, isA<SpRecipientSp>());
      expect(cubit.state.error, isNull);
    });

    test('setValidatedAmount rejects zero and surfaces an error', () {
      final ok = cubit.setValidatedAmount(BigInt.zero);
      expect(ok, isFalse);
      expect(cubit.state.amountSat, isNull);
      expect(cubit.state.error, isA<SpAmountBelowMinimum>());
    });

    test('setValidatedAmount rejects an amount exceeding the balance', () {
      // balance.totalUnifiedSat = 50000
      final ok = cubit.setValidatedAmount(BigInt.from(50001));
      expect(ok, isFalse);
      expect(cubit.state.amountSat, isNull);
      expect(cubit.state.error, isA<SpAmountExceedsBalance>());
    });

    test('setValidatedAmount accepts an amount within the balance', () {
      final ok = cubit.setValidatedAmount(BigInt.from(49999));
      expect(ok, isTrue);
      expect(cubit.state.amountSat, BigInt.from(49999));
      expect(cubit.state.error, isNull);
    });
  });

  group('SP address send flow', () {
    test('previewRecipient sets RecipientView.sp for sp1... address', () {
      cubit.previewRecipient('sp1qexampleaddress');
      expect(cubit.state.hasSendRecipient, true);
      expect(cubit.state.recipient, isA<SpRecipientSp>());
    });

    test('previewRecipient sets RecipientView.sp for tsp1... address', () {
      // A test-network wallet accepts a tsp1 address.
      when(() => networkUsecase.execute()).thenReturn(SpNetwork.regtest);
      cubit.previewRecipient('tsp1qexampleaddress');
      expect(cubit.state.hasSendRecipient, true);
      expect(cubit.state.recipient, isA<SpRecipientSp>());
    });

    test('prepare() calls PrepareSpPaymentUsecase and sets txSimulation',
        () async {
      cubit.previewRecipient('sp1qexampleaddress');
      cubit.setAmount(BigInt.from(5000));

      await cubit.prepare();

      expect(cubit.state.txSimulation, isNotNull);
      expect(cubit.state.hasTxSimulation, true);
      verify(
        () => prepareUsecase.execute(
          recipients: any(named: 'recipients'),
          feerateSatVb: any(named: 'feerateSatVb'),
        ),
      ).called(1);
    });

    test('setMax(true) makes prepare() send a max RecipientView', () async {
      cubit.previewRecipient('sp1qexampleaddress');
      cubit.setMax(true);
      expect(cubit.state.isMax, true);

      await cubit.prepare();

      final captured = verify(
        () => prepareUsecase.execute(
          recipients: captureAny(named: 'recipients'),
          feerateSatVb: any(named: 'feerateSatVb'),
        ),
      ).captured.single as List<SpRecipient>;
      expect(captured.single, isA<SpRecipientSp>());
      expect((captured.single as SpRecipientSp).isMax, true);
    });

    test('signAndBroadcast() completes full SP send flow and sets txid',
        () async {
      cubit.previewRecipient('sp1qexampleaddress');
      cubit.setAmount(BigInt.from(5000));
      // signAndBroadcast requires a confirmed simulation. The UI flow only
      // exposes the Confirm button after prepare() succeeds, so tests that
      // drive Confirm directly must prepare first.
      await cubit.prepare();

      await cubit.signAndBroadcast();

      expect(cubit.state.txid, fakeTxid);
      expect(cubit.state.sendSuccess, true);
      // R4: send-flow inputs must be cleared on success so a back-pop to the
      // confirm page cannot re-enter signAndBroadcast against a stale pinned
      // simulation. txid stays so the success page can still render it.
      expect(cubit.state.recipient, isNull);
      expect(cubit.state.amountSat, isNull);
      expect(cubit.state.txSimulation, isNull);
      verify(
        () => sendUsecase.execute(draft: any(named: 'draft')),
      ).called(1);
    });

    test(
      'signAndBroadcast() after a prior success refuses to re-broadcast (no resetSendFlow between calls)',
      () async {
        // R4 regression: simulates Android system-back / iOS swipe-back from
        // the success page landing on the confirm page, then a second tap on
        // "Sign & Broadcast". With the cubit-side clear-on-success fix, the
        // guard MUST short-circuit the second call.
        cubit.previewRecipient('sp1qexampleaddress');
        cubit.setAmount(BigInt.from(5000));
        await cubit.prepare();

        // First broadcast succeeds.
        await cubit.signAndBroadcast();
        expect(cubit.state.txid, fakeTxid);
        expect(cubit.state.txSimulation, isNull);

        // Second tap, no resetSendFlow, no fresh prepare. Must NOT broadcast
        // again. The cubit clears recipient/amount/simulation on success, so
        // the FIRST defensive guard ("Recipient and amount required") fires
        // before the missing-simulation guard. Either short-circuit is
        // acceptable; the load-bearing assertion is the call-count below.
        await cubit.signAndBroadcast();

        expect(cubit.state.error, isA<SpUnexpected>());
        // The irreversible send ran exactly once across both invocations.
        verify(
          () => sendUsecase.execute(draft: any(named: 'draft')),
        ).called(1);
      },
    );

    test(
      'signAndBroadcast() passes the stored TxSimulation (not rebuilt recipients) to the send usecase',
      () async {
        // Regression: the input/output set the user confirmed in prepare()
        // must be the same set passed to send. Rebuilding from
        // state.recipient/state.amountSat would let coin-store drift change
        // the signed tx between Confirm tap and broadcast.
        cubit.previewRecipient('sp1qexampleaddress');
        cubit.setAmount(BigInt.from(5000));
        await cubit.prepare();

        final confirmed = cubit.state.txSimulation;
        expect(confirmed, isNotNull);

        await cubit.signAndBroadcast();

        final captured = verify(
          () => sendUsecase.execute(draft: captureAny(named: 'draft')),
        ).captured;
        expect(captured.length, 1);
        // The exact simulation instance returned by prepare must be what the
        // send usecase receives, with no intermediate transformation.
        expect(identical(captured.single, confirmed), isTrue);
      },
    );

    test(
      'signAndBroadcast() refuses to sign when no simulation has been confirmed',
      () async {
        // Defense-in-depth: if the cubit is driven outside the prepare→confirm
        // flow (e.g. a test or programmatic listener), send must not be
        // called at all.
        cubit.previewRecipient('sp1qexampleaddress');
        cubit.setAmount(BigInt.from(5000));
        // Intentionally skip prepare().

        await cubit.signAndBroadcast();

        expect(cubit.state.error, isA<SpUnexpected>());
        expect(
          (cubit.state.error! as SpUnexpected).logMessage,
          contains('missing simulation'),
        );
        verifyNever(
          () => sendUsecase.execute(draft: any(named: 'draft')),
        );
      },
    );

    test(
      'signAndBroadcast() survives cubit.close() mid-broadcast: txid is logged, no emit-after-close, send called once',
      () async {
        cubit.previewRecipient('sp1qexampleaddress');
        cubit.setAmount(BigInt.from(5000));
        // confirm a simulation before driving Confirm.
        await cubit.prepare();

        // Capture log records emitted during this test. The repository's
        // `log.info(...)` writes through `Logger.root` (logging package),
        // so installing a listener on the root logger lets us assert that
        // the txid is captured in the device log even when the cubit is
        // closed before it can `emit` the success state.
        final records = <LogRecord>[];
        final previousLevel = Logger.root.level;
        Logger.root.level = Level.ALL;
        final logSub = Logger.root.onRecord.listen(records.add);

        // Gate the send so we control exactly when it resolves. We close the
        // cubit BEFORE releasing the gate, simulating the user popping the SP
        // route while the FRB broadcast worker is still running. Without the
        // `isClosed` guards, the post-await `emit(state.copyWith(txid: txid))`
        // would throw `StateError: emit was called after close`.
        final gate = Completer<Result<String, SpFailure>>();
        when(
          () => sendUsecase.execute(draft: any(named: 'draft')),
        ).thenAnswer((_) async {
          final result = await gate.future;
          if (result case Ok(:final value)) {
            log.info('SP broadcast txid: $value');
          }
          return result;
        });

        // Track any unhandled errors that escape from the in-flight future
        // (the cubit catches its own exceptions, but emit-after-close would
        // bubble as an async error).
        final asyncErrors = <Object>[];
        final inFlight = runZonedGuarded<Future<void>>(
          () => cubit.signAndBroadcast(),
          (error, _) => asyncErrors.add(error),
        )!;

        // Yield once so signAndBroadcast advances past the guards and is
        // awaiting on the send usecase.
        await Future<void>.delayed(Duration.zero);

        // Close mid-broadcast.
        await cubit.close();
        expect(cubit.isClosed, isTrue);

        // Now release the broadcast; tx hits the network AFTER the cubit is
        // gone. The post-await code path must not throw and must log the txid.
        gate.complete(const Ok(fakeTxid));
        await inFlight;
        await Future<void>.delayed(Duration.zero);

        await logSub.cancel();
        Logger.root.level = previousLevel;

        // 1. No emit-after-close exception escaped.
        expect(asyncErrors, isEmpty);

        // 2. Txid was logged to the side channel that survives close().
        final infoLogs = records
            .where((r) => r.level == Level.INFO)
            .map((r) => r.message)
            .toList();
        expect(
          infoLogs.any((m) => m.contains(fakeTxid)),
          isTrue,
          reason:
              'Expected the broadcast txid to be logged at INFO level so it '
              'survives a cubit-close race. Got info logs: $infoLogs',
        );

        // 3. Send ran exactly once (no retry, no duplicate send).
        verify(
          () => sendUsecase.execute(draft: any(named: 'draft')),
        ).called(1);
      },
    );

    test(
      'signAndBroadcast() is re-entrancy guarded: concurrent calls broadcast once',
      () async {
        cubit.previewRecipient('sp1qexampleaddress');
        cubit.setAmount(BigInt.from(5000));
        // confirm a simulation before driving Confirm.
        await cubit.prepare();

        // Make send block until we release the completer, so the second call
        // lands while the first is still in flight.
        final gate = Completer<Result<String, SpFailure>>();
        when(
          () => sendUsecase.execute(draft: any(named: 'draft')),
        ).thenAnswer((_) => gate.future);

        final first = cubit.signAndBroadcast();
        // Fire the second call without awaiting; it should observe
        // isBroadcasting=true and no-op.
        final second = cubit.signAndBroadcast();

        gate.complete(const Ok(fakeTxid));
        await Future.wait([first, second]);

        // The irreversible send sequence must run exactly once even with
        // overlapping invocations.
        verify(
          () => sendUsecase.execute(draft: any(named: 'draft')),
        ).called(1);
        expect(cubit.state.txid, fakeTxid);
        expect(cubit.state.isBroadcasting, false);
      },
    );
  });

  group('Standard address send flow', () {
    test('previewRecipient sets RecipientView.standard for bc1... address', () {
      cubit.previewRecipient('bc1qexampleaddress');
      expect(cubit.state.hasSendRecipient, true);
      expect(cubit.state.recipient, isA<SpRecipientStandard>());
    });

    test('prepare() succeeds for standard address', () async {
      cubit.previewRecipient('bc1qexampleaddress');
      cubit.setAmount(BigInt.from(5000));

      await cubit.prepare();

      expect(cubit.state.txSimulation, isNotNull);
      expect(cubit.state.error, isNull);
    });

    test('signAndBroadcast() completes full standard send flow', () async {
      cubit.previewRecipient('bc1qexampleaddress');
      cubit.setAmount(BigInt.from(5000));
      // confirm a simulation before driving Confirm.
      await cubit.prepare();

      await cubit.signAndBroadcast();

      expect(cubit.state.txid, fakeTxid);
      expect(cubit.state.sendSuccess, true);
    });
  });

  group('Send error handling', () {
    test('prepare() sets error when recipient is null', () async {
      await cubit.prepare();
      expect(cubit.state.error, isNotNull);
    });

    test('prepare() sets error when the usecase throws', () async {
      when(
        () => prepareUsecase.execute(
          recipients: any(named: 'recipients'),
          feerateSatVb: any(named: 'feerateSatVb'),
        ),
      ).thenAnswer(
        (_) async => const Err<SpTxDraft, SpFailure>(
          SpUnexpected('insufficient funds'),
        ),
      );

      cubit.previewRecipient('sp1qtest');
      cubit.setAmount(BigInt.from(999999999));
      await cubit.prepare();

      expect(cubit.state.error, isNotNull);
      expect(cubit.state.isLoading, false);
    });

    test('signAndBroadcast() sets error and resets flags when broadcast throws',
        () async {
      when(
        () => sendUsecase.execute(draft: any(named: 'draft')),
      ).thenAnswer(
        (_) async =>
            const Err<String, SpFailure>(SpUnexpected('broadcast failed')),
      );

      cubit.previewRecipient('sp1qexampleaddress');
      cubit.setAmount(BigInt.from(5000));
      await cubit.prepare();

      await cubit.signAndBroadcast();

      expect(cubit.state.error, isA<SpUnexpected>());
      expect(
        (cubit.state.error! as SpUnexpected).logMessage,
        contains('broadcast failed'),
      );
      expect(cubit.state.isBroadcasting, false);
      expect(cubit.state.isLoading, false);
      // A failed broadcast must not look successful: no txid, no success flag.
      expect(cubit.state.txid, '');
      expect(cubit.state.sendSuccess, false);
    });

    test('resetSendFlow() clears all send state', () {
      cubit.previewRecipient('sp1qtest');
      cubit.setAmount(BigInt.from(5000));

      cubit.resetSendFlow();

      expect(cubit.state.recipient, isNull);
      expect(cubit.state.amountSat, isNull);
      expect(cubit.state.txSimulation, isNull);
      expect(cubit.state.txid, '');
      expect(cubit.state.error, isNull);
    });
  });

  group('scan isolation', () {
    // The send cubit no longer holds the account repository or any scan use
    // case, so it is structurally incapable of triggering a chain scan. These
    // tests assert the send flow still completes its own work without one.
    test('prepare() runs the send flow, not a scan', () async {
      cubit.previewRecipient('sp1qtest');
      cubit.setAmount(BigInt.from(5000));
      await cubit.prepare();

      verify(
        () => prepareUsecase.execute(
          recipients: any(named: 'recipients'),
          feerateSatVb: any(named: 'feerateSatVb'),
        ),
      ).called(1);
      expect(cubit.state.txSimulation, isNotNull);
    });

    test('signAndBroadcast() without a simulation refuses without scanning',
        () async {
      cubit.previewRecipient('sp1qtest');
      cubit.setAmount(BigInt.from(5000));
      // The missing-simulation guard rejects the call (no prepare()).
      await cubit.signAndBroadcast();

      verifyNever(() => sendUsecase.execute(draft: any(named: 'draft')));
      expect(cubit.state.txid, isEmpty);
    });
  });
}
