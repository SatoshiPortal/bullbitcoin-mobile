import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/buy/domain/cancel_abandoned_buy_payjoin_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Ok;

class _MockPayjoinSessions extends Mock implements PayjoinSessions {}

class _MockPayjoinReceiver extends Mock implements PayjoinReceiver {}

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
  late _MockPayjoinSessions sessions;
  late _MockPayjoinReceiver receiver;
  late CancelAbandonedBuyPayjoinUsecase usecase;

  setUpAll(() {
    registerFallbackValue(PayjoinSessionFilter());
  });

  setUp(() {
    sessions = _MockPayjoinSessions();
    receiver = _MockPayjoinReceiver();
    usecase = CancelAbandonedBuyPayjoinUsecase(sessions, receiver);
  });

  test('cancels the ongoing receiver matching an unconfirmed order', () async {
    final session = PayjoinReceiverSession(
      status: PayjoinStatus.started,
      id: 'receiver-1',
      network: BitcoinNetwork.mainnet,
      walletId: 'wallet-1',
      payjoinUri: uri,
      createdAt: DateTime(2026),
      expiresAt: DateTime(2026).add(const Duration(hours: 24)),
    );
    when(() => sessions.list(any())).thenAnswer((_) async => Ok([session]));
    when(
      () => receiver.cancel('receiver-1'),
    ).thenAnswer((_) async => const Ok(null));

    await usecase.execute(
      _order(payinStatus: OrderPayinStatus.awaitingPayment, bip21URI: uri),
    );

    verify(() => receiver.cancel('receiver-1')).called(1);
  });

  test('does not cancel a receiver for a completed order', () async {
    await usecase.execute(
      _order(payinStatus: OrderPayinStatus.completed, bip21URI: uri),
    );

    verifyNever(() => sessions.list(any()));
    verifyNever(() => receiver.cancel(any()));
  });

  for (final status in [
    OrderPayinStatus.inProgress,
    OrderPayinStatus.underReview,
    OrderPayinStatus.awaitingConfirmation,
  ]) {
    test(
      'does not cancel a receiver when the payin is ${status.value}',
      () async {
        await usecase.execute(_order(payinStatus: status, bip21URI: uri));

        verifyNever(() => sessions.list(any()));
        verifyNever(() => receiver.cancel(any()));
      },
    );
  }

  test('does not cancel an unrelated receiver', () async {
    final session = PayjoinReceiverSession(
      status: PayjoinStatus.started,
      id: 'receiver-2',
      network: BitcoinNetwork.mainnet,
      walletId: 'wallet-1',
      payjoinUri: 'bitcoin:bc1qother?pj=https://payjo.in/other',
      createdAt: DateTime(2026),
      expiresAt: DateTime(2026).add(const Duration(hours: 24)),
    );
    when(() => sessions.list(any())).thenAnswer((_) async => Ok([session]));

    await usecase.execute(
      _order(payinStatus: OrderPayinStatus.awaitingPayment, bip21URI: uri),
    );

    verifyNever(() => receiver.cancel(any()));
  });

  test(
    'cancels by stable Payjoin endpoint when the exchange rewrites the amount',
    () async {
      const sessionUri =
          'bitcoin:bc1q0000000000000000000000000000000000000'
          '?amount=0.001&pj=https://payjo.in/session';
      const rewrittenOrderUri =
          'bitcoin:bc1q0000000000000000000000000000000000000'
          '?pj=https://payjo.in/session&amount=0.00098';
      final session = PayjoinReceiverSession(
        status: PayjoinStatus.started,
        id: 'receiver-1',
        network: BitcoinNetwork.mainnet,
        walletId: 'wallet-1',
        payjoinUri: sessionUri,
        createdAt: DateTime(2026),
        expiresAt: DateTime(2026).add(const Duration(hours: 24)),
      );
      when(() => sessions.list(any())).thenAnswer((_) async => Ok([session]));
      when(
        () => receiver.cancel('receiver-1'),
      ).thenAnswer((_) async => const Ok(null));

      await usecase.execute(
        _order(
          payinStatus: OrderPayinStatus.awaitingPayment,
          bip21URI: rewrittenOrderUri,
        ),
      );

      verify(() => receiver.cancel('receiver-1')).called(1);
    },
  );
}
