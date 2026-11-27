import 'package:bull_exchange/src/payin/spend_options_event.dart';
import 'package:fees/fees.dart';
import 'package:bull_exchange/src/pay/domain/pay_state.dart';
import 'package:bull_exchange/src/pay/domain/pay_event.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';

import '../recipients/recipient_fixture.dart';

import 'package:primitives/primitives.dart';

const paySession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'a',
);
const payOtherSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 2,
  sessionId: 'b',
);

final payNow = DateTime.utc(2026, 11, 24, 11);

final paySummary = UserSummary(
  userNumber: 7,
  groups: const ['KYC_IDENTITY_VERIFIED'],
  profile: const UserProfile(firstName: 'Ada', lastName: 'Lovelace'),
  email: 'ada@example.com',
  balances: const [],
  currency: 'CAD',
  dca: const UserDca(isActive: false),
  autoBuy: const UserAutoBuy(
    isActive: false,
    addresses: UserAutoBuyAddresses(),
  ),
);

final payContext = PayContext(paySummary, const []);

const payAppWallet = PayinFromAppWallet('w-1', BtcNetwork.bitcoin);

FiatPaymentOrder payOrder({
  OrderPayinStatus payinStatus = OrderPayinStatus.awaitingPayment,
  OrderPayoutStatus payoutStatus = OrderPayoutStatus.notStarted,
  OrderPaymentMethod payoutMethod = OrderPaymentMethod.bankTransfer,
}) => Order.fiatPayment(
  orderId: 'p-1',
  orderType: OrderType.fiatPayment,
  message: OrderMessage(code: '', message: ''),
  orderNumber: 2,
  payinAmount: 0.0002,
  payinCurrency: 'BTC',
  payoutAmount: 10,
  payoutCurrency: 'CAD',
  payinMethod: OrderPaymentMethod.bitcoin,
  payoutMethod: payoutMethod,
  orderStatus: OrderStatus.inProgress,
  payinStatus: payinStatus,
  payoutStatus: payoutStatus,
  confirmationDeadline: DateTime.utc(2026, 11, 24, 12),
  createdAt: DateTime.utc(2026, 11, 24, 10),
  bitcoinAddress: 'bc1qdeposit',
  isTestnet: false,
) as FiatPaymentOrder;

/// A third party's account: pay takes anyone's recipient.
final payBankRecipient = recipientFixture(
  'r-bank',
  RecipientType.bankTransferCad,
  isOwner: false,
).recipient;
final payInteracRecipient = recipientFixture(
  'r-interac',
  RecipientType.interacEmailCad,
  isOwner: false,
  securityQuestion: 'Pet name?',
  securityAnswer: 'Rex',
).recipient;

PayFlowState applyPay(PayFlowState state, List<PayFlowEvent> events) {
  var current = state;
  for (final event in events) {
    current = current.next(event).state;
  }
  return current;
}

final payLoadingState = payFlowStart(paySession).state;
final payRecipientState = applyPay(payLoadingState, [
  PayContextLoaded(1, Ok(payContext)),
]);
final payRequirementsState = applyPay(payRecipientState, [
  PayRecipientPicked(payInteracRecipient),
]);
final payAmountState = applyPay(payRecipientState, [
  PayRecipientPicked(payBankRecipient),
  const PayAmountChanged(AmountRateArrived(ExchangeCatalog.cad, Ok(50000.0))),
]);
final paySourceState = applyPay(payAmountState, const [
  PayAmountChanged(AmountTyped('10')),
  PayAmountChanged(AmountContinuePressed()),
]);
final payOrderingState = applyPay(paySourceState, const [
  PaySourcePicked(payAppWallet),
]);
const payFees = FeeOptions(
  fastest: RelativeFee(2500),
  economic: RelativeFee(1250),
  slow: RelativeFee(500),
  minRelay: RelativeFee(25),
);

final payReviewState = applyPay(payOrderingState, [
  PayOrderChanged(
    OrderCreateAnswered(
      1,
      GateAdmitted(Ok<Order, ExchangeWriteFailure>(payOrder())),
    ),
  ),
  const PaySpendChanged(SpendFeesLoaded(1, payFees)),
]);
final payPayingState = applyPay(payReviewState, [PayConfirmPressed(payNow)]);
final payDoneState = PayDone(
  (payReviewState as PayOrdering).open,
  payOrder(payinStatus: OrderPayinStatus.inProgress),
  'tx-1',
  null,
);
final payReceiptState = PayDone(
  (payReviewState as PayOrdering).open,
  payOrder(
    payinStatus: OrderPayinStatus.inProgress,
    payoutMethod: OrderPaymentMethod.sinpe,
  ),
  'tx-1',
  WatchWatching<Order>(
    payOrder(
      payinStatus: OrderPayinStatus.inProgress,
      payoutMethod: OrderPaymentMethod.sinpe,
    ),
    0,
    0,
    1,
  ),
);
