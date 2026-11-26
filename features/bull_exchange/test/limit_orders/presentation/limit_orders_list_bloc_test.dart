import 'dart:async';

import 'package:bull_exchange/src/limit_orders/domain/limit_orders_list.dart';
import 'package:bull_exchange/src/limit_orders/presentation/limit_orders_list_bloc.dart';
import 'package:exchange/exchange.dart';
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
  late StreamController<Result<NotificationMessage, ExchangeFailure>>
  notifications;
  late StreamController<void> refreshes;
  late Exchange exchange;

  setUp(() {
    orders = _Orders();
    notifications = StreamController.broadcast();
    refreshes = StreamController.broadcast();
    exchange = exchangeForTesting(
      limitOrders: orders,
      access: fixedAccessForTesting(const ExchangeAccessSignedIn(limitSession)),
    );
  });

  tearDown(() async {
    await notifications.close();
    await refreshes.close();
  });

  LimitOrdersListBloc list() => LimitOrdersListBloc(
    calls: limitOrdersListCallsOf(exchange, limitSession),
    notifications: notifications.stream,
    refreshRequests: refreshes.stream,
  );

  test('loads, and reloads on a refresh request', () async {
    var reads = 0;
    when(() => orders.listActive()).thenAnswer((_) async {
      reads++;
      return Ok([limitOrder()]);
    });
    final bloc = list();
    addTearDown(bloc.close);
    await _settle();
    expect(bloc.state, isA<ListShown>());
    refreshes.add(null);
    await _settle();
    expect(reads, 2);
    expect(bloc.state, isA<ListShown>());
  });

  test(
    'cancel all goes through the gate once and reads the list again',
    () async {
      var reads = 0;
      when(() => orders.listActive()).thenAnswer((_) async {
        reads++;
        return Ok(reads == 1 ? [limitOrder()] : <LimitOrder>[]);
      });
      when(() => orders.cancelAll()).thenAnswer((_) async => const Ok([]));
      final bloc = list();
      addTearDown(bloc.close);
      await _settle();
      bloc
        ..add(const ListCancelAllPressed())
        ..add(const ListCancelAllPressed());
      await _settle();
      verify(() => orders.cancelAll()).called(1);
      expect(reads, 2);
      expect(
        bloc.state,
        isA<ListShown>().having((s) => s.orders, 'orders', isEmpty),
      );
    },
  );
}
