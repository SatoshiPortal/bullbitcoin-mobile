import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fees/fees.dart';
import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/sell/domain/sell_flow.dart';
import 'package:bull_exchange/src/sell/presentation/sell_flow_bloc.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../orders/order_usecase_fakes.dart';
import '../../payin/payin_usecase_fakes.dart';
import '../../payout/payout_requirements_fakes.dart';
import '../sell_fixtures.dart';
import '../sell_usecase_fakes.dart';

/// The sell use cases as fakes; every call is logged with the session it
/// got.
final class _Usecases {
  final log = <String>[];
  final sessions = <ExchangeSession>{};

  void _called(ExchangeSession session, String call) {
    sessions.add(session);
    log.add(call);
  }

  SellFlowBloc bloc({
    required ExchangeSession? session,
    required Stream<ExchangeAccess> accessChanges,
  }) => SellFlowBloc(
    session: session,
    accessChanges: accessChanges,
    loadContext: FakeLoadSellContextUsecase((session) async {
      _called(session, 'load');
      return ReadGot(sellContext);
    }),
    getMarketRate: FakeGetMarketRateUsecase((market) async {
      log.add('rate ${market.currency.code}');
      return const ReadGot(50000.0);
    }),
    createOrder: FakeCreateSellOrderUsecase((session, effect) async {
      _called(session, 'create ${effect.attempt}');
      return OrderCreateAnswered(
        effect.attempt,
        GateAdmitted(WriteDone<Order>(sellOrder())),
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
    refreshOrder: FakeRefreshSellOrderUsecase((session, order) async {
      _called(session, 'refresh ${order.orderId}');
      return ReadGot<Order>(sellOrder());
    }),
    requirements: unusedPayoutRequirements(),
    payin: fakePayin(
      build: FakeBuildPayinUsecase((effect) async {
        log.add('build ${effect.walletId}');
        return const PayinBuildFailed(PayinBuildProblem.insufficientFunds);
      }),
      getOrder: FakeGetOrderUsecase(
        (session, orderId) async => ReadGot<Order>(sellOrder()),
      ),
    ),
    spendOptions: fakeSpendOptions(
      getFees: FakeGetFeeOptionsUsecase((session) async {
        _called(session, 'fees');
        return sellFees;
      }),
      getCoins: FakeGetWalletCoinsUsecase((walletId) async => const []),
      previewPresets: FakePreviewFeePresetsUsecase(
        (shape, fees) async => const {},
      ),
      previewCustom: FakePreviewCustomFeeUsecase(
        (shape, fee) async => const BitcoinFeePreviewSlot(),
      ),
    ),
  );
}

Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'creates once, then Confirm builds the payin from the wallet',
    () => withClock(Clock.fixed(sellNow), () async {
      final calls = _Usecases();
      final bloc = calls.bloc(
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
      expect(calls.sessions, {sellSession});
      expect(
        (bloc.state as SellPaying).payin,
        isA<PayinSendFailed<PayinSpend>>(),
      );
    }),
  );

  test('a session change ends the flow', () async {
    final access = StreamController<ExchangeAccess>();
    final bloc = _Usecases().bloc(
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

  test('without a session the flow starts ended and calls nothing', () async {
    final calls = _Usecases();
    final bloc = calls.bloc(session: null, accessChanges: const Stream.empty());
    addTearDown(bloc.close);
    await _settle();
    expect(bloc.state, isA<SellSessionEnded>());
    expect(calls.log, isEmpty);
  });
}
