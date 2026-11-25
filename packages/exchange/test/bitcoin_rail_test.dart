import 'package:exchange/exchange.dart';
import 'package:exchange/src/data/btc_network_wire.dart';
import 'package:test/test.dart';

final _message = OrderMessage(code: '', message: '');

Order _sell({
  OrderPaymentMethod payinMethod = OrderPaymentMethod.bitcoin,
  String? bitcoinAddress,
  String? liquidAddress,
  String? lightningInvoice,
}) => Order.sell(
  orderId: 'o-1',
  orderType: OrderType.sell,
  message: _message,
  orderNumber: 1,
  payinAmount: 0.001,
  payinCurrency: 'BTC',
  payoutAmount: 100,
  payoutCurrency: 'CAD',
  payinMethod: payinMethod,
  payoutMethod: OrderPaymentMethod.cadBalance,
  orderStatus: OrderStatus.inProgress,
  payinStatus: OrderPayinStatus.notStarted,
  payoutStatus: OrderPayoutStatus.notStarted,
  createdAt: DateTime.utc(2026, 11, 24),
  bitcoinAddress: bitcoinAddress,
  liquidAddress: liquidAddress,
  lightningInvoice: lightningInvoice,
  isTestnet: true,
);

void main() {
  test('one rail per network, and back', () {
    for (final network in BtcNetwork.values) {
      expect(BitcoinRails.of(network).network, network);
      expect(network.rail, same(BitcoinRails.of(network)));
    }
    expect(BitcoinRails.all.map((r) => r.network), BtcNetwork.values);
  });

  test('what each rail allows', () {
    expect(
      {
        for (final rail in BitcoinRails.all)
          rail.network: (
            appWallet: rail.canBeAppWallet,
            externalPayin: rail.canBeExternalPayin,
            buyAppWallet: rail.canBeBuyAppWallet,
            buyExternal: rail.canBeBuyExternal,
            payjoin: rail.supportsPayjoin,
            method: rail.payinMethod,
          ),
      },
      {
        BtcNetwork.bitcoin: (
          appWallet: true,
          externalPayin: true,
          buyAppWallet: true,
          buyExternal: true,
          payjoin: true,
          method: OrderPaymentMethod.bitcoin,
        ),
        BtcNetwork.liquid: (
          appWallet: true,
          externalPayin: true,
          buyAppWallet: true,
          buyExternal: false,
          payjoin: false,
          method: OrderPaymentMethod.liquid,
        ),
        BtcNetwork.lightning: (
          appWallet: false,
          externalPayin: true,
          buyAppWallet: false,
          buyExternal: false,
          payjoin: false,
          method: OrderPaymentMethod.lnInvoice,
        ),
      },
    );
  });

  test('wire values come from the one mapping', () {
    for (final rail in BitcoinRails.all) {
      expect(rail.orderNetworkWire, BtcNetworkWire.orderNetwork(rail.network));
      expect(
        rail.recipientTypeWire,
        BtcNetworkWire.recipientType(rail.network),
      );
    }
  });

  test('the rail of a payin method', () {
    expect(
      BitcoinRails.ofPayinMethod(OrderPaymentMethod.bitcoin),
      BitcoinRails.bitcoin,
    );
    expect(
      BitcoinRails.ofPayinMethod(OrderPaymentMethod.liquid),
      BitcoinRails.liquid,
    );
    expect(
      BitcoinRails.ofPayinMethod(OrderPaymentMethod.lnInvoice),
      BitcoinRails.lightning,
    );
    expect(BitcoinRails.ofPayinMethod(OrderPaymentMethod.sepa), isNull);
    expect(BitcoinRails.ofPayinMethod(OrderPaymentMethod.unknown), isNull);
  });

  group('deposit', () {
    final both = _sell(bitcoinAddress: 'tb1q', liquidAddress: 'tlq1');

    test('each rail reads only its own field', () {
      expect(
        BitcoinRails.bitcoin.depositOf(both),
        const DepositGiven(OnchainDeposit('tb1q')),
      );
      expect(
        BitcoinRails.liquid.depositOf(
          _sell(
            payinMethod: OrderPaymentMethod.liquid,
            bitcoinAddress: 'tb1q',
            liquidAddress: 'tlq1',
          ),
        ),
        const DepositGiven(LiquidDeposit('tlq1')),
      );
      expect(
        BitcoinRails.lightning.depositOf(
          _sell(
            payinMethod: OrderPaymentMethod.lnInvoice,
            lightningInvoice: 'lntb1',
          ),
        ),
        const DepositGiven(LightningInvoiceDeposit('lntb1')),
      );
    });

    test('an order paid in on another rail is not this rail\'s', () {
      expect(
        BitcoinRails.liquid.depositOf(both),
        const DepositOnOtherRail(OrderPaymentMethod.bitcoin),
      );
    });

    test('a missing or empty field is no deposit', () {
      expect(BitcoinRails.bitcoin.depositOf(_sell()), const DepositNotGiven());
      expect(
        BitcoinRails.bitcoin.depositOf(_sell(bitcoinAddress: '')),
        const DepositNotGiven(),
      );
    });

    test('a Lightning order without an address keeps its deposit (PAY-1)', () {
      final order = _sell(
        payinMethod: OrderPaymentMethod.lnInvoice,
        lightningInvoice: 'lntb1',
      );
      expect(
        BitcoinRails.lightning.keepsDeposit(
          const LightningInvoiceDeposit('lntb1'),
          order,
        ),
        isTrue,
      );
    });

    test('a moved or missing deposit is not kept (SELL-4)', () {
      const expected = OnchainDeposit('tb1q');
      expect(BitcoinRails.bitcoin.keepsDeposit(expected, both), isTrue);
      expect(
        BitcoinRails.bitcoin.keepsDeposit(
          expected,
          _sell(bitcoinAddress: 'tb1other'),
        ),
        isFalse,
      );
      expect(BitcoinRails.bitcoin.keepsDeposit(expected, _sell()), isFalse);
    });
  });
}
