import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/cancel_payjoin_receiver_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/get_payjoins_usecase.dart';
import 'package:bb_mobile/features/buy/domain/cancel_abandoned_buy_payjoin_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetPayjoinsUsecase extends Mock implements GetPayjoinsUsecase {}

class _MockCancelPayjoinReceiverUsecase extends Mock
    implements CancelPayjoinReceiverUsecase {}

BuyOrder _order({required OrderPayinStatus payinStatus, String? bip21URI}) =>
    Order.buy(
          orderId: 'order-1',
          orderType: OrderType.buy,
          message: OrderMessage(code: '', message: ''),
          orderNumber: 1,
          payinAmount: 100,
          payinCurrency: 'CAD',
          payoutAmount: 0.001,
          payoutCurrency: 'BTC',
          payinMethod: OrderPaymentMethod.bankTransfer,
          payoutMethod: OrderPaymentMethod.bitcoin,
          orderStatus: OrderStatus.awaitingConfirmation,
          payinStatus: payinStatus,
          payoutStatus: OrderPayoutStatus.notStarted,
          createdAt: DateTime(2026),
          bip21URI: bip21URI,
          isTestnet: false,
        )
        as BuyOrder;

void main() {
  const uri =
      'bitcoin:bc1q0000000000000000000000000000000000000'
      '?amount=0.001&pj=https://payjo.in/session';
  late _MockGetPayjoinsUsecase getPayjoins;
  late _MockCancelPayjoinReceiverUsecase cancelReceiver;
  late CancelAbandonedBuyPayjoinUsecase usecase;

  setUp(() {
    getPayjoins = _MockGetPayjoinsUsecase();
    cancelReceiver = _MockCancelPayjoinReceiverUsecase();
    usecase = CancelAbandonedBuyPayjoinUsecase(
      getPayjoins,
      cancelReceiver,
    );
  });

  test('cancels the ongoing receiver matching an unconfirmed order', () async {
    final receiver =
        Payjoin.receiver(
              id: 'receiver-1',
              isTestnet: false,
              walletId: 'wallet-1',
              pjUri: uri,
              createdAt: DateTime(2026),
              expiresAt: DateTime(2026).add(const Duration(hours: 24)),
            )
            as PayjoinReceiver;
    when(
      () => getPayjoins.execute(onlyOngoing: true),
    ).thenAnswer((_) async => [receiver]);
    when(() => cancelReceiver.execute('receiver-1')).thenAnswer((_) async {});

    await usecase.execute(
      _order(payinStatus: OrderPayinStatus.awaitingPayment, bip21URI: uri),
    );

    verify(() => cancelReceiver.execute('receiver-1')).called(1);
  });

  test('does not cancel a receiver for a completed order', () async {
    await usecase.execute(
      _order(payinStatus: OrderPayinStatus.completed, bip21URI: uri),
    );

    verifyNever(
      () => getPayjoins.execute(onlyOngoing: any(named: 'onlyOngoing')),
    );
    verifyNever(() => cancelReceiver.execute(any()));
  });

  test('does not cancel an unrelated receiver', () async {
    final receiver =
        Payjoin.receiver(
              id: 'receiver-2',
              isTestnet: false,
              walletId: 'wallet-1',
              pjUri: 'bitcoin:bc1qother?pj=https://payjo.in/other',
              createdAt: DateTime(2026),
              expiresAt: DateTime(2026).add(const Duration(hours: 24)),
            )
            as PayjoinReceiver;
    when(
      () => getPayjoins.execute(onlyOngoing: true),
    ).thenAnswer((_) async => [receiver]);

    await usecase.execute(
      _order(payinStatus: OrderPayinStatus.awaitingPayment, bip21URI: uri),
    );

    verifyNever(() => cancelReceiver.execute(any()));
  });
}
