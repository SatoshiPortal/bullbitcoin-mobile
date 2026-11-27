import 'package:bull_exchange/src/buy/domain/buy_state.dart';
import 'package:bull_exchange/src/buy/domain/buy_event.dart';
import 'package:bull_exchange/src/buy/domain/buy_effect.dart';
import 'package:bull_exchange/src/buy/domain/buy_payjoin_uris.dart';
import 'package:bull_exchange/src/buy/domain/usecases/create_buy_order_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../buy_fixtures.dart';
import '../../buy_test_ports.dart';

const _bip21 = 'bitcoin:bc1qreceive?pj=https://relay.example/abc';

OrderSendCreate<BuyRequest> _sendOf(BuyFlowNext next) =>
    next.effects.whereType<BuyOrderEffect>().single.effect
        as OrderSendCreate<BuyRequest>;

/// The create the flow sends for 10 CAD to the liquid wallet (no payjoin).
OrderSendCreate<BuyRequest> _plain() => _sendOf(
  applyBuy(buyEntryState, const [
    BuyAmountChanged(AmountTyped('10')),
    BuyContinuePressed(),
  ]),
);

/// The create the flow sends for 10 CAD to the on-chain wallet, with
/// payjoin.
OrderSendCreate<BuyRequest> _withPayjoin() => _sendOf(
  applyBuy(buyEntryState, [
    BuyDestinationPicked(buyBitcoinWallet.option),
    BuyDestinationChanged(
      PickResolved(buyBitcoinWallet.option, const Ok(buyBitcoinDestination)),
    ),
    const BuyAmountChanged(AmountTyped('10')),
    const BuyContinuePressed(),
  ]),
);

final _opened = Ok<PayjoinReceiverSession, PayjoinFailure>(
  buyReceiverSession(uri: _bip21),
);

Future<OrderCreateAnswered<BuyRequest, BuyOrder>> _create(
  OrderSendCreate<BuyRequest> send, {
  required BuyTestOrders orders,
  required BuyTestReceiver receiver,
  required BuyPayjoinUris uris,
  InMemoryUnknownWriteJournal? journal,
  List<ExchangeEnvironment>? environments,
}) => CreateBuyOrderUsecase(
  exchangeForTesting(
    orders: (environment) {
      environments?.add(environment);
      return orders;
    },
    unknownWrites: journal,
    readSessionPoint: () async =>
        const Ok((environment: ExchangeEnvironment.mainnet, epoch: 1)),
  ),
  receiver,
  uris,
).execute(buySession, send);

void main() {
  test('a plain payout places the order with no receiver', () async {
    final orders = BuyTestOrders()..placed = Ok(buyOrder());
    final receiver = BuyTestReceiver();
    final environments = <ExchangeEnvironment>[];
    final answer = await _create(
      _plain(),
      orders: orders,
      receiver: receiver,
      uris: BuyPayjoinUris(),
      environments: environments,
    );
    expect(answer.attempt, 1);
    expect(answer.answer, isA<Ok<BuyOrder, ExchangeGatedWriteFailure>>());
    expect(orders.log, ['place lq1qreceive CAD liquid owner=true bip21=null']);
    expect(receiver.log, isEmpty);
    expect(environments, [ExchangeEnvironment.mainnet]);
  });

  test('a payjoin wallet opens a receiver and the done order keeps its '
      'URI', () async {
    final orders = BuyTestOrders()..placed = Ok(buyOrder());
    final receiver = BuyTestReceiver(_opened);
    final uris = BuyPayjoinUris();
    final answer = await _create(
      _withPayjoin(),
      orders: orders,
      receiver: receiver,
      uris: uris,
    );
    expect(receiver.log, ['start w-btc']);
    expect(receiver.started.single.network, BitcoinNetwork.mainnet);
    expect(receiver.started.single.address, 'bc1qreceive');
    expect(orders.log, [
      'place bc1qreceive CAD bitcoin owner=true bip21=$_bip21',
    ]);
    final done = answer.answer;
    expect(
      (done as Ok<BuyOrder, ExchangeGatedWriteFailure>).value.bip21URI,
      _bip21,
    );
    expect(uris.withBip21(buyOrder()).bip21URI, _bip21);
  });

  test('a receiver that does not open leaves a plain order', () async {
    final orders = BuyTestOrders()..placed = Ok(buyOrder());
    await _create(
      _withPayjoin(),
      orders: orders,
      receiver: BuyTestReceiver(),
      uris: BuyPayjoinUris(),
    );
    expect(orders.log.single, endsWith('bip21=null'));
  });

  test('an unknown outcome is journaled and keeps the URI for the order a '
      'find matches', () async {
    final journal = InMemoryUnknownWriteJournal();
    final orders = BuyTestOrders()
      ..placed = const Err(ExchangeWriteOutcomeUnknownFailure('lost'));
    final receiver = BuyTestReceiver(_opened);
    final uris = BuyPayjoinUris();
    final send = _withPayjoin();
    await _create(
      send,
      orders: orders,
      receiver: receiver,
      uris: uris,
      journal: journal,
    );
    final (entry, _) = journal.entries.single;
    expect(entry.kind, UnknownWriteKind.orderCreate);
    expect(entry.sessionEpoch, buySession.epoch);
    expect(receiver.log, ['start w-btc']);
    expect(uris.withBip21(buyOrder()).bip21URI, isNull);
    uris.adopt(send.request, 'b-1');
    expect(uris.withBip21(buyOrder()).bip21URI, _bip21);
  });

  test('a create that took no effect drops its receiver', () async {
    final orders = BuyTestOrders()
      ..placed = const Err(
        ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
      );
    final receiver = BuyTestReceiver(_opened);
    await _create(
      _withPayjoin(),
      orders: orders,
      receiver: receiver,
      uris: BuyPayjoinUris(),
    );
    expect(receiver.log, ['start w-btc', 'cancel pj-1']);
  });
}
