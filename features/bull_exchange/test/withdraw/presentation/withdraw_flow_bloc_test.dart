import 'dart:async';

import 'package:bull_exchange/src/payout/payout_requirements_runner.dart';
import 'package:bull_exchange/src/withdraw/domain/withdraw_flow.dart';
import 'package:bull_exchange/src/withdraw/presentation/withdraw_flow_bloc.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../payout/payout_requirements_fakes.dart';
import '../withdraw_fixtures.dart';

final class _Calls {
  final log = <String>[];
  final sessions = <ExchangeSession>[];
  Completer<GatedWrite<ExchangeWrite<WithdrawOrder>>> confirmAnswer =
      Completer();
  ExchangeRead<Order> reread = ReadGot(withdrawOrder());

  PayoutRequirementsUsecases get requirements => unusedPayoutRequirements();

  WithdrawFlowCalls of(ExchangeSession session) {
    sessions.add(session);
    return (
      loadContext: () async {
        log.add('load');
        return ReadGot(withdrawContext);
      },
      rate: (market) async {
        log.add('rate ${market.currency.code}');
        return const ReadGot(50000.0);
      },
      create: (effect) async {
        log.add('create ${effect.attempt}');
        return OrderCreateAnswered(
          effect.attempt,
          GateAdmitted(WriteDone(withdrawOrder())),
        );
      },
      findCreated: (request, sentAt) async {
        log.add('find');
        return const ReadMissing();
      },
      confirm: (effect) async {
        log.add('confirm ${effect.attempt}');
        return ConfirmAnswered(effect.attempt, await confirmAnswer.future);
      },
      readOrder: (orderId) async {
        log.add('read $orderId');
        return reread;
      },
      requirements: requirements,
    );
  }
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _Calls calls;
  late StreamController<ExchangeAccess> access;
  late WithdrawFlowBloc bloc;

  setUp(() {
    calls = _Calls();
    access = StreamController<ExchangeAccess>.broadcast();
    bloc = WithdrawFlowBloc(
      calls: calls.of,
      session: withdrawSession,
      accessChanges: access.stream,
    );
  });

  tearDown(() async {
    await bloc.close();
    await access.close();
  });

  Future<void> send(List<WithdrawFlowEvent> events) async {
    for (final event in events) {
      bloc.add(event);
      await _settle();
    }
    await _settle();
  }

  test('runs each state effect with the flow session', () async {
    await _settle();
    await _settle();
    expect(calls.sessions, [withdrawSession]);
    expect(calls.log, ['load', 'rate CAD']);
    expect(bloc.state, isA<WithdrawAmount>());
    await send([
      const WithdrawAmountChanged(AmountTyped('10')),
      const WithdrawAmountChanged(AmountContinuePressed()),
      WithdrawRecipientPicked(withdrawBankRecipient),
    ]);
    expect(calls.log, ['load', 'rate CAD', 'create 1']);
    expect(bloc.state, isA<WithdrawReview>());
  });

  test('Confirm pressed twice sends one confirm; an unknown outcome '
      're-reads the order', () async {
    await _settle();
    await send([
      const WithdrawAmountChanged(AmountTyped('10')),
      const WithdrawAmountChanged(AmountContinuePressed()),
      WithdrawRecipientPicked(withdrawBankRecipient),
      const WithdrawConfirmPressed(),
      const WithdrawConfirmPressed(),
      const WithdrawBackPressed(),
    ]);
    expect(calls.log.where((l) => l.startsWith('confirm')), ['confirm 1']);
    expect(bloc.state, isA<WithdrawConfirming>());
    calls.reread = ReadGot(withdrawOrder(status: OrderStatus.inProgress));
    calls.confirmAnswer.complete(
      const GateAdmitted(WriteOutcomeUnknown('lost')),
    );
    await _settle();
    await _settle();
    await _settle();
    expect(calls.log.last, 'read w-1');
    expect(bloc.state, isA<WithdrawDone>());
  });

  test('a session change ends the flow', () async {
    await _settle();
    access.add(const ExchangeAccessSignedOut(ExchangeEnvironment.mainnet));
    await _settle();
    expect(bloc.state, isA<WithdrawSessionEnded>());
  });

  test('without a session nothing runs', () async {
    final before = [...calls.sessions];
    final none = WithdrawFlowBloc(
      calls: calls.of,
      session: null,
      accessChanges: const Stream.empty(),
    );
    addTearDown(none.close);
    await _settle();
    expect(none.state, isA<WithdrawSessionEnded>());
    // Only the setUp's bloc bound calls to a session.
    expect(calls.sessions, before);
  });
}
