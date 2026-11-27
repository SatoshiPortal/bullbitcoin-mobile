import 'package:bull_exchange/src/buy/domain/buy_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';

const buySession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'a',
);
const buyOtherSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 2,
  sessionId: 'b',
);

UserSummary buySummaryWith({
  List<UserBalance> balances = const [
    UserBalance(amount: 100, currencyCode: 'CAD'),
  ],
  List<String> groups = const ['KYC_IDENTITY_VERIFIED'],
}) => UserSummary(
  userNumber: 7,
  groups: groups,
  profile: const UserProfile(firstName: 'Ada', lastName: 'Lovelace'),
  email: 'ada@example.com',
  balances: balances,
  currency: 'CAD',
  dca: const UserDca(isActive: false),
  autoBuy: const UserAutoBuy(
    isActive: false,
    addresses: UserAutoBuyAddresses(),
  ),
  payjoinReceiveEnabled: true,
);

final buySummary = buySummaryWith();

const buyBitcoinWallet = BuyPayoutWallet(
  walletId: 'w-btc',
  rail: BtcNetwork.bitcoin,
  label: 'Savings',
  canPayjoin: true,
);
const buyLiquidWallet = BuyPayoutWallet(
  walletId: 'w-lq',
  rail: BtcNetwork.liquid,
  isDefault: true,
);

BuyContext buyContextWith({
  UserSummary? summary,
  List<BuyPayoutWallet> wallets = const [buyBitcoinWallet, buyLiquidWallet],
  bool payjoinAllowed = true,
  List<UnknownWrite> openEntries = const [],
}) => BuyContext(
  summary: summary ?? buySummary,
  wallets: wallets,
  payjoinAllowed: payjoinAllowed,
  openEntries: openEntries,
);

final buyContext = buyContextWith();

const buyLiquidDestination = DestinationAppWallet(
  'w-lq',
  BtcNetwork.liquid,
  'lq1qreceive',
);
const buyBitcoinDestination = DestinationAppWallet(
  'w-btc',
  BtcNetwork.bitcoin,
  'bc1qreceive',
);

final buyDeadline = DateTime.utc(2026, 11, 24, 12);
final buyBeforeDeadline = DateTime.utc(2026, 11, 24, 11);

BuyOrder buyOrder({
  String id = 'b-1',
  OrderStatus status = OrderStatus.awaitingConfirmation,
  OrderPayoutStatus payout = OrderPayoutStatus.notStarted,
  String? bip21,
}) => Order.buy(
  orderId: id,
  orderType: OrderType.buy,
  message: OrderMessage(code: '', message: ''),
  orderNumber: 1,
  payinAmount: 10,
  payinCurrency: 'CAD',
  payoutAmount: 0.0002,
  payoutCurrency: 'BTC',
  payinMethod: OrderPaymentMethod.cadBalance,
  payoutMethod: OrderPaymentMethod.liquid,
  orderStatus: status,
  payinStatus: OrderPayinStatus.notStarted,
  payoutStatus: payout,
  confirmationDeadline: buyDeadline,
  createdAt: DateTime.utc(2026, 11, 24, 10),
  liquidAddress: 'lq1qreceive',
  bip21URI: bip21,
  isTestnet: false,
) as BuyOrder;

GateAdmitted<Result<T, ExchangeWriteFailure>> buyDone<T>(T value) =>
    GateAdmitted(Ok(value));

BuyFlowNext applyBuy(BuyFlowState state, List<BuyFlowEvent> events) {
  var next = BuyFlowNext.stay(state);
  for (final event in events) {
    next = next.state.next(event);
  }
  return next;
}

final buyLoadingState = buyFlowStart(buySession).state;
final buyEntryState = applyBuy(buyLoadingState, [
  BuyContextLoaded(1, Ok(buyContext)),
  const BuyAmountChanged(AmountRateArrived(ExchangeCatalog.cad, Ok(50000.0))),
  BuyDestinationChanged(
    PickResolved(buyLiquidWallet.option, const Ok(buyLiquidDestination)),
  ),
]).state;
final buyOrderingState = applyBuy(buyEntryState, const [
  BuyAmountChanged(AmountTyped('10')),
  BuyContinuePressed(),
]).state;
final buyReviewState = applyBuy(buyOrderingState, [
  BuyOrderChanged(OrderCreateAnswered(1, buyDone(buyOrder()))),
]).state;
final buyConfirmingState = applyBuy(buyReviewState, [
  BuyConfirmPressed(buyBeforeDeadline),
]).state;
final buyDoneState = applyBuy(buyConfirmingState, [
  BuyConfirmChanged(
    ConfirmAnswered(1, buyDone(buyOrder(status: OrderStatus.inProgress))),
  ),
]).state;
