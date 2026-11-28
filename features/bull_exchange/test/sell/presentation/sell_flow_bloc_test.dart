import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fees/fees.dart';
import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/payout/payout_requirements_runner.dart';
import 'package:bull_exchange/src/sell/presentation/sell_flow.dart';
import 'package:bull_exchange/src/sell/presentation/sell_flow_bloc.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;

import '../sell_fixtures.dart';

final class _Calls {
  final log = <String>[];

  PayoutRequirementsCalls get requirements => (
    loadVirtualIban: () => throw StateError('no virtual IBAN in this test'),
    createVirtualIban: () => throw StateError('no virtual IBAN in this test'),
    findVirtualIban: () => throw StateError('no virtual IBAN in this test'),
    payeeStatus: (_) => throw StateError('no payee in this test'),
    activatePayee: (_) => throw StateError('no payee in this test'),
  );

  PayinCalls get payin => (
    build: (effect) async {
      log.add('build ${effect.walletId}');
      return const PayinBuildFailed(PayinBuildProblem.insufficientFunds);
    },
    send: (built) async => throw StateError('not sent in this test'),
    readOrder: (orderId) async => ReadGot(sellOrder()),
    txSeen: (txid) async => null,
    watchPayjoin: (sessionId) => const Stream.empty(),
    retryPayjoin: (sessionId) async {},
    journalUnknown: (orderId, network, txid) async {},
  );

  SellFlowCalls of(ExchangeSession session) => (
    loadContext: () async {
      log.add('load');
      return ReadGot(sellContext);
    },
    rate: (market) async {
      log.add('rate ${market.currency.code}');
      return const ReadGot(50000.0);
    },
    create: (effect) async {
      log.add('create ${effect.attempt}');
      return OrderCreateAnswered(
        effect.attempt,
        GateAdmitted(WriteDone<Order>(sellOrder())),
      );
    },
    findCreated: (request, sentAt) async => const ReadMissing(),
    refresh: (order) async {
      log.add('refresh ${order.orderId}');
      return ReadGot<Order>(sellOrder());
    },
    requirements: requirements,
    payin: payin,
    spend: (
      fees: () async {
        log.add('fees');
        return sellFees;
      },
      coins: (walletId) async => const [],
      presets: (shape, fees) async => const {},
      custom: (shape, fee) async => const BitcoinFeePreviewSlot(),
    ),
    gate: ExchangeWriteGate(),
  );
}

Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'a witnessed choice revoked before handling cannot create a Sell order',
    () => withClock(Clock.fixed(sellNow), () async {
      final calls = _Calls();
      final bloc = SellFlowBloc(
        calls: calls.of,
        session: sellSession,
        accessChanges: const Stream.empty(),
      );
      addTearDown(bloc.close);
      await _settle();
      bloc.add(const SellAmountChanged(AmountTyped('10')));
      bloc.add(const SellAmountChanged(AmountContinuePressed()));
      await _settle();
      expect(bloc.state, isA<SellSource>());
      var live = true;
      bloc.add(
        SellSourcePicked(
          PayinFromAppWallet.witnessed(
            PayinWalletWitness(
              walletId: sellAppWallet.walletId,
              network: BitcoinNetwork.mainnet,
              generation: 1,
              currentReceipt: () => live ? true : null,
            ),
          ),
        ),
      );
      live = false;
      await _settle();
      expect(bloc.state, isA<SellSource>());
      expect(calls.log.where((call) => call.startsWith('create')), isEmpty);
    }),
  );

  test(
    'creates once, then Confirm builds the payin from the wallet',
    () => withClock(Clock.fixed(sellNow), () async {
      final calls = _Calls();
      final bloc = SellFlowBloc(
        calls: calls.of,
        session: sellSession,
        accessChanges: const Stream.empty(),
      );
      addTearDown(bloc.close);
      await _settle();
      for (final event in [
        const SellAmountChanged(AmountTyped('10')),
        const SellAmountChanged(AmountContinuePressed()),
        const SellSourcePicked(sellAppWallet),
        const SellPayoutPicked(SellPayoutChoice.balance),
      ]) {
        bloc.add(event);
      }
      await _settle();
      expect(bloc.state, isA<SellOrdering>());
      expect(
        (bloc.state as SellOrdering).order,
        isA<OrderQuoted<SellRequest, Order>>(),
      );
      bloc
        ..add(SellConfirmPressed(sellNow))
        ..add(SellConfirmPressed(sellNow));
      await _settle();
      expect(calls.log, ['load', 'rate CAD', 'create 1', 'fees', 'build w-1']);
      expect(
        (bloc.state as SellPaying).payin,
        isA<PayinSendFailed<PayinSpend>>(),
      );
    }),
  );

  test('a session change ends the flow', () async {
    final access = StreamController<ExchangeAccess>();
    final bloc = SellFlowBloc(
      calls: _Calls().of,
      session: sellSession,
      accessChanges: access.stream,
    );
    addTearDown(bloc.close);
    await _settle();
    access.add(const ExchangeAccessSignedOut(ExchangeEnvironment.mainnet));
    await _settle();
    expect(bloc.state, isA<SellSessionEnded>());
    await access.close();
  });
}
