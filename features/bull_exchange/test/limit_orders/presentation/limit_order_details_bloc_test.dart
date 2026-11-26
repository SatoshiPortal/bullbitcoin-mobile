import 'dart:async';

import 'package:bull_exchange/src/limit_orders/domain/limit_order_cancel.dart';
import 'package:bull_exchange/src/limit_orders/presentation/limit_order_details_bloc.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_details_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../limit_order_fixtures.dart';

class _Orders extends Mock implements ExchangeLimitOrders {}

Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _Orders orders;
  late Exchange exchange;

  setUp(() {
    orders = _Orders();
    exchange = exchangeForTesting(
      limitOrders: orders,
      access: fixedAccessForTesting(const ExchangeAccessSignedIn(limitSession)),
    );
  });

  LimitDetailsBloc details() => LimitDetailsBloc(
    calls: (session) => limitDetailsCallsOf(exchange, session),
    session: limitSession,
    orderId: 'lo-1',
    accessChanges: const Stream.empty(),
  );

  test('a failed cancel shows the order as read again (LIM-3)', () async {
    var reads = 0;
    when(() => orders.get('lo-1')).thenAnswer((_) async {
      reads++;
      return Ok(
        limitOrder(
          status: reads == 1
              ? LimitOrderStatus.active
              : LimitOrderStatus.executed,
        ),
      );
    });
    when(() => orders.cancel('lo-1')).thenAnswer(
      (_) async => const Err(
        ExchangeLimitOrderFailure(ExchangeLimitOrderProblem.cancel, 'filled'),
      ),
    );
    final bloc = details();
    addTearDown(bloc.close);
    await _settle();
    expect(bloc.state, isA<DetailsShown>());
    bloc.add(const DetailsCancelChanged(CancelPressed()));
    await _settle();
    expect(
      bloc.state,
      isA<DetailsShown>().having(
        (s) => s.cancel,
        'cancel',
        isA<CancelIdle>()
            .having((c) => c.order.status, 'status', LimitOrderStatus.executed)
            .having((c) => c.problem, 'problem', isA<CancelNotApplied>()),
      ),
    );
    verify(() => orders.cancel('lo-1')).called(1);
  });

  test('a cancelled order closes as changed', () async {
    when(() => orders.get('lo-1')).thenAnswer((_) async => Ok(limitOrder()));
    when(() => orders.cancel('lo-1')).thenAnswer(
      (_) async => Ok(limitOrder(status: LimitOrderStatus.cancelled)),
    );
    final bloc = details();
    addTearDown(bloc.close);
    await _settle();
    bloc
      ..add(const DetailsCancelChanged(CancelPressed()))
      ..add(const DetailsCancelChanged(CancelPressed()));
    await _settle();
    bloc.add(const DetailsBackPressed());
    await _settle();
    expect(bloc.state, const DetailsClosed(changed: true));
    verify(() => orders.cancel('lo-1')).called(1);
  });

  test('a missing order is not found, not a network failure', () async {
    when(() => orders.get('lo-1')).thenAnswer(
      (_) async => const Err(
        ExchangeLimitOrderFailure(ExchangeLimitOrderProblem.notFound, '404'),
      ),
    );
    final bloc = details();
    addTearDown(bloc.close);
    await _settle();
    expect(
      bloc.state,
      isA<DetailsFailed>().having(
        (s) => s.problem,
        'problem',
        isA<ReadProblemMissing>(),
      ),
    );
  });
}
