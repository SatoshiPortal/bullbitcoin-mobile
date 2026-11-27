import 'dart:async';

import 'package:bull_exchange/src/buy/presentation/buy_accelerate_bloc.dart';
import 'package:bull_exchange/src/buy/domain/buy_accelerate_state.dart';
import 'package:bull_exchange/src/buy/domain/buy_accelerate_event.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../orders/order_usecase_fakes.dart';
import '../buy_fixtures.dart';
import '../buy_usecase_fakes.dart';

import 'package:primitives/primitives.dart';

final _quote = AccelerateQuote(
  buyOrder(status: OrderStatus.inProgress),
  const AccelerateFee(satPerVbyte: 2.5, sats: 350, fiatPerBitcoin: 50000),
  const [],
);

/// The accelerate use cases as fakes; every call is logged with the
/// session it got.
final class _Calls {
  final log = <String>[];
  final sessions = <ExchangeSession>{};
  Completer<Result<BuyOrder, ExchangeGatedWriteFailure>> answer = Completer();
  Result<Order, ExchangeReadFailure> reread = Ok(
    buyOrder(status: OrderStatus.inProgress),
  );

  void _called(ExchangeSession session, String call) {
    sessions.add(session);
    log.add(call);
  }

  AccelerateFlowBloc bloc({
    required ExchangeSession? session,
    required Stream<ExchangeAccess> accessChanges,
  }) => AccelerateFlowBloc(
    session: session,
    orderId: 'b-1',
    accessChanges: accessChanges,
    loadQuote: FakeLoadAccelerateQuoteUsecase((session, orderId) async {
      _called(session, 'load $orderId');
      return Ok(_quote);
    }),
    accelerateOrder: FakeAccelerateBuyOrderUsecase((session, effect) async {
      _called(session, 'accelerate ${effect.attempt}');
      return ConfirmAnswered(effect.attempt, await answer.future);
    }),
    getOrder: FakeGetOrderUsecase((session, orderId) async {
      _called(session, 'read $orderId');
      return reread;
    }),
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
    bloc = calls.bloc(session: buySession, accessChanges: access.stream);
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
    calls.answer.complete(Ok(buyOrder(status: OrderStatus.inProgress)));
    await _settle();
    expect(bloc.state, isA<AccelerateDone>());
    expect(calls.sessions, {buySession});
  });

  test('an unknown accelerate re-reads, never accelerates again', () async {
    await _settle();
    bloc.add(const AccelerateConfirmPressed());
    await _settle();
    calls.answer.complete(
      const Err(ExchangeWriteOutcomeUnknownFailure('lost')),
    );
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

  test('without a session nothing runs', () async {
    final none = _Calls();
    final ended = none.bloc(session: null, accessChanges: const Stream.empty());
    addTearDown(ended.close);
    await _settle();
    expect(ended.state, isA<AccelerateSessionEnded>());
    expect(none.log, isEmpty);
  });
}
