import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';

const payinSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 's',
);

const payinTestnetSession = ExchangeSession(
  environment: ExchangeEnvironment.testnet,
  epoch: 2,
  sessionId: 't',
);

/// A sell order awaiting 0.001 BTC; [deadline] defaults to an hour from now.
SellOrder payinOrder({DateTime? deadline, String? payjoinBip21}) => Order.sell(
  orderId: 'o-1',
  orderType: OrderType.sell,
  message: OrderMessage(code: '', message: ''),
  orderNumber: 1,
  payinAmount: 0.001,
  payinCurrency: 'BTC',
  payoutAmount: 100,
  payoutCurrency: 'CAD',
  payinMethod: OrderPaymentMethod.bitcoin,
  payoutMethod: OrderPaymentMethod.cadBalance,
  orderStatus: OrderStatus.inProgress,
  payinStatus: OrderPayinStatus.awaitingPayment,
  payoutStatus: OrderPayoutStatus.notStarted,
  confirmationDeadline:
      deadline ?? DateTime.now().add(const Duration(hours: 1)),
  createdAt: DateTime.utc(2026, 11, 24),
  bitcoinAddress: 'tb1q',
  isTestnet: true,
) as SellOrder;

const payinTarget = OnchainDeposit('tb1q');
const payinWalletSpend = PayinWalletSpend(
  'w1',
  PayinSpendOptions(
    fee: PayinFeeRate(250),
    replaceByFee: true,
    coins: {},
    payjoin: false,
  ),
);
const payinBuilt = PayinBuilt<PayinSpend>(
  payinWalletSpend,
  'tx1',
  SignedBitcoinPayin<String>('signed'),
);
