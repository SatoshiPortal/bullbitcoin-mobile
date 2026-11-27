import 'dart:async';

import 'package:bull_exchange/src/withdraw/domain/withdraw_flow.dart';
import 'package:bull_exchange/src/withdraw/presentation/withdraw_flow_bloc.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../orders/order_usecase_fakes.dart';
import '../../payout/payout_requirements_fakes.dart';
import '../withdraw_fixtures.dart';
import '../withdraw_usecase_fakes.dart';

/// Fake use cases that log each call with the session it got.
final class _Usecases {
  final log = <String>[];
  final sessions = <ExchangeSession>{};
  Completer<GatedWrite<ExchangeWrite<WithdrawOrder>>> confirmAnswer =
      Completer();
  ExchangeRead<Order> reread = ReadGot(withdrawOrder());

  void _called(ExchangeSession session, String call) {
    sessions.add(session);
    log.add(call);
  }

  WithdrawFlowBloc bloc(
    ExchangeSession? session,
    Stream<ExchangeAccess> accessChanges,
  ) => WithdrawFlowBloc(
    session: session,
    accessChanges: accessChanges,
    loadContext: FakeLoadWithdrawContextUsecase((session) async {
      _called(session, 'load');
      return ReadGot(withdrawContext);
    }),
    getMarketRate: FakeGetMarketRateUsecase((_, market) async {
      log.add('rate ${market.currency.code}');
      return const ReadGot(50000.0);
    }),
    createOrder: FakeCreateWithdrawOrderUsecase((session, effect) async {
      _called(session, 'create ${effect.attempt}');
      return OrderCreateAnswered(
        effect.attempt,
        GateAdmitted(WriteDone(withdrawOrder())),
      );
    }),
    findCreatedOrder: FakeFindCreatedOrderUsecase((
      session,
      journal,
      sentAt,
    ) async {
      _called(session, 'find');
      return const ReadMissing();
    }),
    confirmOrder: FakeConfirmWithdrawOrderUsecase((session, effect) async {
      _called(session, 'confirm ${effect.attempt}');
      return ConfirmAnswered(effect.attempt, await confirmAnswer.future);
    }),
    getOrder: FakeGetOrderUsecase((session, orderId) async {
      _called(session, 'read $orderId');
      return reread;
    }),
    requirements: unusedPayoutRequirements(),
  );
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _Usecases usecases;
  late StreamController<ExchangeAccess> access;
  late WithdrawFlowBloc bloc;

  setUp(() {
    usecases = _Usecases();
    access = StreamController<ExchangeAccess>.broadcast();
    bloc = usecases.bloc(withdrawSession, access.stream);
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
    expect(usecases.log, ['load', 'rate CAD']);
    expect(bloc.state, isA<WithdrawAmount>());
    await send([
      const WithdrawAmountChanged(AmountTyped('10')),
      const WithdrawAmountChanged(AmountContinuePressed()),
      WithdrawRecipientPicked(withdrawBankRecipient),
    ]);
    expect(usecases.log, ['load', 'rate CAD', 'create 1']);
    expect(usecases.sessions, {withdrawSession});
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
    expect(usecases.log.where((l) => l.startsWith('confirm')), ['confirm 1']);
    expect(bloc.state, isA<WithdrawConfirming>());
    usecases.reread = ReadGot(withdrawOrder(status: OrderStatus.inProgress));
    usecases.confirmAnswer.complete(
      const GateAdmitted(WriteOutcomeUnknown('lost')),
    );
    await _settle();
    await _settle();
    await _settle();
    expect(usecases.log.last, 'read w-1');
    expect(usecases.sessions, {withdrawSession});
    expect(bloc.state, isA<WithdrawDone>());
  });

  test('a session change ends the flow', () async {
    await _settle();
    access.add(const ExchangeAccessSignedOut(ExchangeEnvironment.mainnet));
    await _settle();
    expect(bloc.state, isA<WithdrawSessionEnded>());
  });

  test('without a session nothing runs', () async {
    final none = _Usecases();
    final bloc = none.bloc(null, const Stream.empty());
    addTearDown(bloc.close);
    await _settle();
    expect(bloc.state, isA<WithdrawSessionEnded>());
    expect(none.log, isEmpty);
  });
}
