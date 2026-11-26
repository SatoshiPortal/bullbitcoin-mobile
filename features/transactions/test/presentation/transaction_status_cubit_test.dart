import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:transactions/testing.dart';

import 'animation_fixtures.dart';

class _MockWatch extends Mock implements WatchSettlementTransactionUsecase {}

class _Reader implements PaymentAnimationPreferencesReader {
  final Result<bool, PreferencesFailure> result;

  _Reader(this.result);

  @override
  Future<Result<bool, PreferencesFailure>> readShowPaymentAnimations() async =>
      result;
}

const _a = TransactionSettlementTarget(walletId: 'wallet', txId: 'a');
const _b = TransactionSettlementTarget(walletId: 'wallet', txId: 'b');

void main() {
  late _MockWatch watch;
  late Map<TransactionSettlementTarget, StreamController<WalletTransaction>>
  streams;
  late TransactionStatusCubit cubit;

  setUpAll(() => registerFallbackValue(_a));

  setUp(() {
    watch = _MockWatch();
    streams = {};
    when(() => watch.execute(any())).thenAnswer((invocation) {
      final target =
          invocation.positionalArguments.single as TransactionSettlementTarget;
      return (streams[target] = StreamController<WalletTransaction>()).stream;
    });
    cubit = TransactionStatusCubit(
      readAnimations: ReadTransactionPaymentAnimationsUsecase(
        _Reader(const Ok(true)),
      ),
      watchSettlement: watch,
    );
    addTearDown(cubit.close);
  });

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  group('preference', () {
    test('is read once and exposed', () async {
      expect(cubit.state.animationsEnabled, isNull);
      await cubit.loadPreference();
      expect(cubit.state.animationsEnabled, isTrue);
    });

    test('keeps animations on when it cannot be read', () async {
      final unreadable = ReadTransactionPaymentAnimationsUsecase(
        _Reader(const Err(PreferencesReadFailure('unreadable'))),
      );
      expect(await unreadable.execute(), isTrue);
    });

    test('honours an explicit off', () async {
      final off = ReadTransactionPaymentAnimationsUsecase(
        _Reader(const Ok(false)),
      );
      expect(await off.execute(), isFalse);
    });
  });

  group('settlement observation', () {
    test('the same target never resubscribes', () async {
      cubit.observeSettlement(_a);
      cubit.observeSettlement(_a);
      await flush();
      verify(() => watch.execute(_a)).called(1);
    });

    test('a changed target replaces the subscription', () async {
      cubit.observeSettlement(_a);
      final first = streams[_a]!;
      expect(first.hasListener, isTrue);
      cubit.observeSettlement(_b);
      await flush();
      expect(first.hasListener, isFalse);
      expect(streams[_b]!.hasListener, isTrue);
      expect(cubit.state.settlementTarget, _b);
      expect(cubit.state.settlement, isNull);
    });

    test('no target stops the observation', () async {
      cubit.observeSettlement(_a);
      final stream = streams[_a]!;
      cubit.observeSettlement(null);
      await flush();
      expect(stream.hasListener, isFalse);
      expect(cubit.state.settlementTarget, isNull);
    });

    test('survives the details handoff to the same target', () async {
      // The swap-id load resolves to the wallet transaction and cancels its
      // swap watch; the displayed transaction changes, the target does not.
      cubit.observeSettlement(_a);
      final stream = streams[_a]!;
      stream.add(walletTx('a', incoming: true));
      await flush();
      cubit.observeSettlement(_a);
      await flush();
      expect(stream.hasListener, isTrue);
      expect(cubit.state.settlement?.txId, 'a');
    });

    test('confirmation needs the exact settlement transaction', () async {
      cubit.observeSettlement(_a);
      streams[_a]!.add(walletTx('a'));
      await flush();
      expect(cubit.state.settlementPending, isTrue);
      expect(cubit.state.settlementConfirmed, isFalse);
      streams[_a]!.add(walletTx('other', confirmed: true));
      await flush();
      expect(cubit.state.settlementConfirmed, isFalse);
      streams[_a]!.add(walletTx('a', confirmed: true));
      await flush();
      expect(cubit.state.settlementConfirmed, isTrue);
      expect(cubit.state.settlementPending, isFalse);
    });

    test('an event from a replaced observation is ignored', () async {
      cubit.observeSettlement(_a);
      final old = streams[_a]!;
      cubit.observeSettlement(_b);
      old.add(walletTx('a', confirmed: true));
      await flush();
      expect(cubit.state.settlement, isNull);
    });

    test('close cancels the observation and ignores late events', () async {
      cubit.observeSettlement(_a);
      final stream = streams[_a]!;
      await cubit.close();
      expect(stream.hasListener, isFalse);
      cubit.observeSettlement(_b);
      expect(streams.containsKey(_b), isFalse);
    });
  });
}
