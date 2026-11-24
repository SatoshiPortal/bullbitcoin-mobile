import 'package:bull_exchange/src/payin/spend_options.dart';
import 'package:fees/fees.dart';
import 'package:bull_exchange/src/sell/presentation/sell_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';

import '../recipients/recipient_fixture.dart';

const sellSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'a',
);
const sellOtherSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 2,
  sessionId: 'b',
);

final sellNow = DateTime.utc(2026, 11, 24, 11);

final sellSummary = UserSummary(
  userNumber: 7,
  groups: const [],
  profile: const UserProfile(firstName: 'Ada', lastName: 'Lovelace'),
  email: 'ada@example.com',
  balances: const [UserBalance(amount: 0, currencyCode: 'CAD')],
  currency: 'CAD',
  dca: const UserDca(isActive: false),
  autoBuy: const UserAutoBuy(
    isActive: false,
    addresses: UserAutoBuyAddresses(),
  ),
);

final sellContext = SellContext(sellSummary, const []);

const sellAppWallet = PayinFromAppWallet('w-1', BtcNetwork.bitcoin);

SellOrder sellOrder({
  OrderPayinStatus payinStatus = OrderPayinStatus.awaitingPayment,
}) => Order.sell(
  orderId: 's-1',
  orderType: OrderType.sell,
  message: OrderMessage(code: '', message: ''),
  orderNumber: 1,
  payinAmount: 0.0002,
  payinCurrency: 'BTC',
  payoutAmount: 10,
  payoutCurrency: 'CAD',
  payinMethod: OrderPaymentMethod.bitcoin,
  payoutMethod: OrderPaymentMethod.cadBalance,
  orderStatus: OrderStatus.inProgress,
  payinStatus: payinStatus,
  payoutStatus: OrderPayoutStatus.notStarted,
  confirmationDeadline: DateTime.utc(2026, 11, 24, 12),
  createdAt: DateTime.utc(2026, 11, 24, 10),
  bitcoinAddress: 'bc1qdeposit',
  isTestnet: false,
) as SellOrder;

final sellBankRecipient = recipientFixture(
  'r-bank',
  RecipientType.bankTransferCad,
  isOwner: true,
).recipient;
final sellInteracRecipient = recipientFixture(
  'r-interac',
  RecipientType.interacEmailCad,
  isOwner: true,
  securityQuestion: 'Pet name?',
  securityAnswer: 'Rex',
).recipient;
final sellThirdPartyRecipient = recipientFixture(
  'r-third',
  RecipientType.bankTransferCad,
  isOwner: false,
).recipient;

SellFlowState applySell(SellFlowState state, List<SellFlowEvent> events) {
  var current = state;
  for (final event in events) {
    current = transitionSellFlow(current, event).state;
  }
  return current;
}

final sellLoadingState = sellFlowStart(sellSession).state;
final sellAmountState = applySell(sellLoadingState, [
  SellContextLoaded(1, ReadGot(sellContext)),
  const SellAmountChanged(
    AmountRateArrived(ExchangeCatalog.cad, ReadGot(50000.0)),
  ),
]);
final sellSourceState = applySell(sellAmountState, const [
  SellAmountChanged(AmountTyped('10')),
  SellAmountChanged(AmountContinuePressed()),
]);
final sellPayoutState = applySell(sellSourceState, const [
  SellSourcePicked(sellAppWallet),
]);
final sellRecipientState = applySell(sellPayoutState, const [
  SellPayoutPicked(SellPayoutChoice.recipient),
]);
final sellRequirementsState = applySell(sellRecipientState, [
  SellRecipientPicked(sellInteracRecipient),
]);
final sellOrderingFromRecipient = applySell(sellRecipientState, [
  SellRecipientPicked(sellBankRecipient),
]);
final sellOrderingState = applySell(sellPayoutState, const [
  SellPayoutPicked(SellPayoutChoice.balance),
]);
const sellFees = FeeOptions(
  fastest: RelativeFee(2500),
  economic: RelativeFee(1250),
  slow: RelativeFee(500),
  minRelay: RelativeFee(25),
);

/// The review's payin options once the fee estimates are in: fastest, RBF
/// on, the wallet picks the coins, payjoin on.
const sellDefaultOptions = PayinSpendOptions(
  fee: PayinFeeRate(2500),
  replaceByFee: true,
  coins: {},
  payjoin: true,
);

final sellReviewState = applySell(sellOrderingState, [
  SellOrderChanged(
    OrderCreateAnswered(1, GateAdmitted(WriteDone<Order>(sellOrder()))),
  ),
  const SellSpendChanged(SpendFeesLoaded(1, sellFees)),
]);
final sellPayingState = applySell(sellReviewState, [
  SellConfirmPressed(sellNow),
]);
final sellDoneState = SellDone(
  (sellReviewState as SellOrdering).open,
  sellOrder(payinStatus: OrderPayinStatus.inProgress),
  'tx-1',
);
