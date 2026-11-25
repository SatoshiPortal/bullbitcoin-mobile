import 'dart:async';

import 'package:bull_exchange/src/buy/presentation/buy_accelerate_bloc.dart';
import 'package:bull_exchange/src/buy/presentation/buy_accelerate_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';

import '../buy_fixtures.dart';

final _quote = AccelerateQuote(
  buyOrder(status: OrderStatus.inProgress),
  const AccelerateFee(satPerVbyte: 2.5, sats: 350, fiatPerBitcoin: 50000),
  const [],
);

final class _Calls {
  final log = <String>[];
  Completer<GatedWrite<ExchangeWrite<BuyOrder>>> answer = Completer();
  ExchangeRead<Order> reread = ReadGot(
    buyOrder(status: OrderStatus.inProgress),
  );

  AccelerateFlowCalls of(ExchangeSession session) => (
    load: (orderId) async {
      log.add('load $orderId');
      return ReadGot(_quote);
    },
    accelerate: (effect) async {
      log.add('accelerate ${effect.attempt}');
      return ConfirmAnswered(effect.attempt, await answer.future);
    },
    readOrder: (orderId) async {
      log.add('read $orderId');
      return reread;
    },
  );
}

Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _Calls calls;
  late StreamController<ExchangeAccess> access;
  late AccelerateFlowBloc bloc;

  setUp(() {
    calls = _Calls();
    access = StreamController<ExchangeAccess>.broadcast();
    bloc = AccelerateFlowBloc(
      calls: calls.of,
      session: buySession,
      orderId: 'b-1',
      accessChanges: access.stream,
    );
  });

  tearDown(() async {
    await bloc.close();
    await access.close();
  });

  test('loads the order by id, accelerates once, then is done', () async {
    await _settle();
    expect(calls.log, ['load b-1']);
    expect(bloc.state, isA<AccelerateReady>());
    bloc
      ..add(const AccelerateConfirmPressed())
      ..add(const AccelerateConfirmPressed());
    await _settle();
    expect(calls.log, ['load b-1', 'accelerate 1']);
    calls.answer.complete(
      GateAdmitted(WriteDone(buyOrder(status: OrderStatus.inProgress))),
    );
    await _settle();
    expect(bloc.state, isA<AccelerateDone>());
  });

  test('an unknown accelerate re-reads, never accelerates again', () async {
    await _settle();
    bloc.add(const AccelerateConfirmPressed());
    await _settle();
    calls.answer.complete(const GateAdmitted(WriteOutcomeUnknown('lost')));
    await _settle();
    expect(calls.log.last, 'read b-1');
    expect(
      (bloc.state as AccelerateConfirming).confirm,
      isA<ConfirmUnverified<AccelerateTarget, BuyOrder>>(),
    );
    expect(calls.log.where((l) => l.startsWith('accelerate')), [
      'accelerate 1',
    ]);
  });

  test('a session change ends the flow', () async {
    await _settle();
    access.add(const ExchangeAccessSignedOut(ExchangeEnvironment.mainnet));
    await _settle();
    expect(bloc.state, isA<AccelerateSessionEnded>());
  });
}
