import 'package:clock/clock.dart';
import 'package:fees/fees.dart';
import 'package:bull_exchange/src/pay/presentation/pay_flow.dart';
import 'package:bull_exchange/src/pay/presentation/pay_flow_bloc.dart';
import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/payout/payout_requirements_runner.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;

import '../pay_fixtures.dart';

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
    readOrder: (orderId) async => ReadGot<Order>(payOrder()),
    txSeen: (txid) async => null,
    watchPayjoin: (sessionId) => const Stream.empty(),
    retryPayjoin: (sessionId) async {},
    journalUnknown: (orderId, network, txid) async {},
  );

  PayFlowCalls of(ExchangeSession session) => (
    loadContext: () async {
      log.add('load');
      return ReadGot(payContext);
    },
    rate: (market) async {
      log.add('rate ${market.currency.code}');
      return const ReadGot(50000.0);
    },
    create: (effect) async {
      log.add('create ${effect.attempt}');
      return OrderCreateAnswered(
        effect.attempt,
        GateAdmitted(WriteDone<Order>(payOrder())),
      );
    },
    findCreated: (request, sentAt) async => const ReadMissing(),
    refresh: (order) async => ReadGot<Order>(payOrder()),
    requirements: requirements,
    payin: payin,
    spend: (
      fees: () async {
        log.add('fees');
        return payFees;
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
    'a witnessed choice revoked before handling cannot create a Pay order',
    () => withClock(Clock.fixed(payNow), () async {
      final calls = _Calls();
      final bloc = PayFlowBloc(
        calls: calls.of,
        session: paySession,
        accessChanges: const Stream.empty(),
      );
      addTearDown(bloc.close);
      await _settle();
      bloc.add(PayRecipientPicked(payBankRecipient));
      await _settle();
      bloc.add(const PayAmountChanged(AmountTyped('10')));
      bloc.add(const PayAmountChanged(AmountContinuePressed()));
      await _settle();
      expect(bloc.state, isA<PaySource>());
      var live = true;
      bloc.add(
        PaySourcePicked(
          PayinFromAppWallet.witnessed(
            PayinWalletWitness(
              walletId: payAppWallet.walletId,
              network: BitcoinNetwork.mainnet,
              generation: 1,
              currentReceipt: () => live ? true : null,
            ),
          ),
        ),
      );
      live = false;
      await _settle();
      expect(bloc.state, isA<PaySource>());
      expect(calls.log.where((call) => call.startsWith('create')), isEmpty);
    }),
  );

  test(
    'creates once, then Confirm builds the payin from the wallet',
    () => withClock(Clock.fixed(payNow), () async {
      final calls = _Calls();
      final bloc = PayFlowBloc(
        calls: calls.of,
        session: paySession,
        accessChanges: const Stream.empty(),
      );
      addTearDown(bloc.close);
      await _settle();
      bloc.add(PayRecipientPicked(payBankRecipient));
      // The rate is read once the recipient fixes the currency.
      await _settle();
      for (final event in const [
        PayAmountChanged(AmountTyped('10')),
        PayAmountChanged(AmountContinuePressed()),
        PaySourcePicked(payAppWallet),
      ]) {
        bloc.add(event);
      }
      await _settle();
      expect(
        (bloc.state as PayOrdering).order,
        isA<OrderQuoted<PayRequest, Order>>(),
      );
      bloc
        ..add(PayConfirmPressed(payNow))
        ..add(PayConfirmPressed(payNow));
      await _settle();
      expect(calls.log, ['load', 'rate CAD', 'create 1', 'fees', 'build w-1']);
      expect(
        (bloc.state as PayPaying).payin,
        isA<PayinSendFailed<PayinSpend>>(),
      );
    }),
  );
}
