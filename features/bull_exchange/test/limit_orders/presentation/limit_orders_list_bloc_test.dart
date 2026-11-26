import 'dart:async';

import 'package:bull_exchange/src/limit_orders/domain/limit_orders_list.dart';
import 'package:bull_exchange/src/limit_orders/presentation/limit_orders_list_bloc.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../limit_order_fixtures.dart';
import '../limit_order_usecase_fakes.dart';

Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late StreamController<Result<NotificationMessage, ExchangeFailure>>
  notifications;
  late StreamController<void> refreshes;
  late List<String> log;
  late List<ExchangeSession?> sessions;

  setUp(() {
    notifications = StreamController.broadcast();
    refreshes = StreamController.broadcast();
    log = [];
    sessions = [];
  });

  tearDown(() async {
    await notifications.close();
    await refreshes.close();
  });

  LimitOrdersListBloc list(List<LimitOrder> Function(int read) orders) {
    var reads = 0;
    return LimitOrdersListBloc(
      session: limitSession,
      getActiveOrders: FakeGetActiveLimitOrdersUsecase(() async {
        log.add('list');
        return ReadGot(orders(++reads));
      }),
      cancelAllOrders: FakeCancelAllLimitOrdersUsecase((session) async {
        sessions.add(session);
        log.add('cancelAll');
        return const CancelAllDone();
      }),
      notifications: notifications.stream,
      refreshRequests: refreshes.stream,
    );
  }

  test('loads, and reloads on a refresh request', () async {
    final bloc = list((_) => [limitOrder()]);
    addTearDown(bloc.close);
    await _settle();
    expect(bloc.state, isA<ListShown>());
    refreshes.add(null);
    await _settle();
    expect(log, ['list', 'list']);
    expect(bloc.state, isA<ListShown>());
  });

  test(
    'cancel all goes through the gate once and reads the list again',
    () async {
      final bloc = list((read) => read == 1 ? [limitOrder()] : <LimitOrder>[]);
      addTearDown(bloc.close);
      await _settle();
      bloc
        ..add(const ListCancelAllPressed())
        ..add(const ListCancelAllPressed());
      await _settle();
      expect(log, ['list', 'cancelAll', 'list']);
      expect(sessions, [limitSession]);
      expect(
        bloc.state,
        isA<ListShown>().having((s) => s.orders, 'orders', isEmpty),
      );
    },
  );
}
