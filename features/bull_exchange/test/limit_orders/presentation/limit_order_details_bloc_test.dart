import 'dart:async';

import 'package:bull_exchange/src/limit_orders/domain/limit_order_cancel.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_details_flow.dart';
import 'package:bull_exchange/src/limit_orders/presentation/limit_order_details_bloc.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';

import '../limit_order_fixtures.dart';
import '../limit_order_usecase_fakes.dart';

Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// The details use cases as fakes answering [reads] in turn and [cancel];
/// every call is logged, with the session it got where it takes one.
final class _Calls {
  final List<ExchangeRead<LimitOrder>> reads;
  final LimitCancelAnswer cancel;
  final log = <String>[];
  final sessions = <ExchangeSession>{};

  _Calls(this.reads, {this.cancel = const CancelAnsweredUnsure()});

  LimitDetailsBloc bloc({ExchangeSession? session = limitSession}) =>
      LimitDetailsBloc(
        session: session,
        orderId: 'lo-1',
        accessChanges: const Stream.empty(),
        getOrder: FakeGetLimitOrderUsecase((_, orderId) async {
          log.add('get $orderId');
          return reads.length > 1 ? reads.removeAt(0) : reads.single;
        }),
        cancelOrder: FakeCancelLimitOrderUsecase((session, orderId) async {
          sessions.add(session);
          log.add('cancel $orderId');
          return cancel;
        }),
      );
}

void main() {
  test('a failed cancel shows the order as read again (LIM-3)', () async {
    final calls = _Calls([
      ReadGot(limitOrder()),
      ReadGot(limitOrder(status: LimitOrderStatus.executed)),
    ]);
    final bloc = calls.bloc();
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
    expect(calls.log, ['get lo-1', 'cancel lo-1', 'get lo-1']);
    expect(calls.sessions, {limitSession});
  });

  test('a cancelled order closes as changed', () async {
    final calls = _Calls(
      [ReadGot(limitOrder())],
      cancel: CancelAnsweredOrder(
        limitOrder(status: LimitOrderStatus.cancelled),
      ),
    );
    final bloc = calls.bloc();
    addTearDown(bloc.close);
    await _settle();
    bloc
      ..add(const DetailsCancelChanged(CancelPressed()))
      ..add(const DetailsCancelChanged(CancelPressed()));
    await _settle();
    bloc.add(const DetailsBackPressed());
    await _settle();
    expect(bloc.state, const DetailsClosed(changed: true));
    expect(calls.log.where((l) => l.startsWith('cancel')), ['cancel lo-1']);
  });

  test('a missing order is not found, not a network failure', () async {
    final bloc = _Calls([const ReadMissing()]).bloc();
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

  test('without a session nothing runs', () async {
    final calls = _Calls([ReadGot(limitOrder())]);
    final bloc = calls.bloc(session: null);
    addTearDown(bloc.close);
    await _settle();
    expect(calls.log, isEmpty);
  });
}
