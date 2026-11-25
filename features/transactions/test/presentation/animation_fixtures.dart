import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Sats;
import 'package:swaps/order_swaps.dart';
import 'package:transactions/testing.dart';

WalletTransaction walletTx(
  String txId, {
  bool confirmed = false,
  bool incoming = false,
  String walletId = 'wallet',
}) => WalletTransaction(
  walletId: walletId,
  network: BitcoinNetwork.testnet,
  direction: incoming
      ? WalletTransactionDirection.incoming
      : WalletTransactionDirection.outgoing,
  status: confirmed
      ? WalletTransactionStatus.confirmed
      : WalletTransactionStatus.pending,
  txId: txId,
  amountSat: 1000,
  feeSat: 10,
  vsize: 140,
  inputs: const [],
  outputs: const [],
  isRbf: false,
);

OrderSwapRecord orderSwap({
  OrderSwapLocalStatus status = OrderSwapLocalStatus.payoutInProgress,
  String? sourceWalletId = 'source',
  String? destinationWalletId,
  OrderSwapNetwork out = OrderSwapNetwork.liquid,
  String? payoutTxId,
  String? payinTxId = 'payin',
}) => OrderSwapRecord(
  localId: 'order-swap',
  purpose: OrderSwapPurpose.transfer,
  environment: OrderSwapEnvironment.testnet,
  inNetwork: OrderSwapNetwork.bitcoin,
  outNetwork: out,
  isInAmountFixed: true,
  requestedAmountSat: BigInt.from(1000),
  sourceWalletId: sourceWalletId,
  destinationWalletId: destinationWalletId,
  destination: 'destination',
  fallback: 'fallback',
  createdAt: DateTime.utc(2026),
  localStatus: status,
  localPayinTransactionId: payinTxId,
  order: OrderSwap(
    orderId: 'server',
    orderNumber: 1,
    inNetwork: OrderSwapNetwork.bitcoin,
    outNetwork: out,
    payinAmountSat: BigInt.from(1000),
    payoutAmountSat: BigInt.from(990),
    payinCurrency: 'BTC',
    payoutCurrency: 'L-BTC',
    payinMethod: 'bitcoin',
    payoutMethod: 'liquid',
    orderType: 'swap',
    orderStatus: 'pending',
    payinStatus: 'pending',
    payoutStatus: 'pending',
    messageCode: '',
    liquidTransactionId: out == OrderSwapNetwork.liquid ? payoutTxId : null,
    bitcoinTransactionId: out == OrderSwapNetwork.bitcoin ? payoutTxId : null,
    createdAt: DateTime.utc(2026),
    confirmationDeadline: DateTime.utc(2100),
  ),
);

PayjoinSenderSession senderSession(
  PayjoinStatus status, {
  String? txId,
  String original = 'original',
}) => PayjoinSenderSession(
  status: status,
  uri: 'bitcoin:tb1q?pj=https://payjo.in',
  network: BitcoinNetwork.testnet,
  walletId: 'wallet',
  originalTransactionId: original,
  transactionId: txId,
  amount: Sats.fromInt(50000),
  createdAt: DateTime.utc(2026),
  expiresAt: DateTime.utc(2100),
);

PayjoinReceiverSession receiverSession(
  PayjoinStatus status, {
  String? txId,
  String original = 'original',
}) => PayjoinReceiverSession(
  status: status,
  id: '0123456789abcdef',
  network: BitcoinNetwork.testnet,
  walletId: 'wallet',
  payjoinUri: 'bitcoin:tb1q?pj=https://payjo.in',
  hasOriginalTransaction: true,
  hasProposal: true,
  originalTransactionId: original,
  transactionId: txId,
  amount: Sats.fromInt(50000),
  createdAt: DateTime.utc(2026),
  expiresAt: DateTime.utc(2100),
);

BuyOrder buyOrder({
  OrderPayoutStatus payout = OrderPayoutStatus.inProgress,
  OrderPaymentMethod method = OrderPaymentMethod.bitcoin,
}) => Order.buy(
  orderId: 'buy',
  orderType: OrderType.buy,
  message: OrderMessage(code: '', message: ''),
  orderNumber: 1,
  payinAmount: 100,
  payinCurrency: 'CAD',
  payoutAmount: 0.001,
  payoutCurrency: 'BTC',
  payinMethod: OrderPaymentMethod.cadBalance,
  payoutMethod: method,
  orderStatus: OrderStatus.inProgress,
  payinStatus: OrderPayinStatus.completed,
  payoutStatus: payout,
  createdAt: DateTime.utc(2026),
  isTestnet: true,
) as BuyOrder;

Order sellOrder() => Order.sell(
  orderId: 'sell',
  orderType: OrderType.sell,
  message: OrderMessage(code: '', message: ''),
  orderNumber: 2,
  payinAmount: 0.001,
  payinCurrency: 'BTC',
  payoutAmount: 100,
  payoutCurrency: 'CAD',
  payinMethod: OrderPaymentMethod.bitcoin,
  payoutMethod: OrderPaymentMethod.cadBalance,
  orderStatus: OrderStatus.inProgress,
  payinStatus: OrderPayinStatus.inProgress,
  payoutStatus: OrderPayoutStatus.inProgress,
  createdAt: DateTime.utc(2026),
  isTestnet: true,
);
