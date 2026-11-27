import 'package:bull_exchange/src/withdraw/domain/withdraw_state.dart';
import 'package:bull_exchange/src/withdraw/domain/withdraw_event.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';

import '../recipients/recipient_fixture.dart';

import 'package:primitives/primitives.dart';

const withdrawSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'a',
);

final withdrawSummary = UserSummary(
  userNumber: 7,
  groups: const [],
  profile: const UserProfile(firstName: 'Ada', lastName: 'Lovelace'),
  email: 'ada@example.com',
  balances: const [UserBalance(amount: 100, currencyCode: 'CAD')],
  currency: 'CAD',
  dca: const UserDca(isActive: false),
  autoBuy: const UserAutoBuy(
    isActive: false,
    addresses: UserAutoBuyAddresses(),
  ),
);

final withdrawContext = WithdrawContext(withdrawSummary, const []);

WithdrawOrder withdrawOrder({
  OrderStatus status = OrderStatus.awaitingConfirmation,
}) => Order.withdraw(
  orderId: 'w-1',
  orderType: OrderType.withdraw,
  message: OrderMessage(code: '', message: ''),
  orderNumber: 1,
  payinAmount: 10,
  payinCurrency: 'CAD',
  payoutAmount: 10,
  payoutCurrency: 'CAD',
  payinMethod: OrderPaymentMethod.cadBalance,
  payoutMethod: OrderPaymentMethod.eTransfer,
  orderStatus: status,
  payinStatus: OrderPayinStatus.notStarted,
  payoutStatus: OrderPayoutStatus.notStarted,
  createdAt: DateTime.utc(2026, 11, 24),
  isTestnet: false,
) as WithdrawOrder;

final withdrawBankRecipient = recipientFixture(
  'r-bank',
  RecipientType.bankTransferCad,
  isOwner: true,
).recipient;

WithdrawFlowState applyWithdraw(
  WithdrawFlowState state,
  List<WithdrawFlowEvent> events,
) {
  var current = state;
  for (final event in events) {
    current = current.next(event).state;
  }
  return current;
}

final withdrawAmountState = applyWithdraw(
  withdrawFlowStart(withdrawSession).state,
  [
    WithdrawContextLoaded(1, Ok(withdrawContext)),
    const WithdrawAmountChanged(
      AmountRateArrived(ExchangeCatalog.cad, Ok(50000.0)),
    ),
  ],
);

final withdrawRecipientState = applyWithdraw(withdrawAmountState, const [
  WithdrawAmountChanged(AmountTyped('10')),
  WithdrawAmountChanged(AmountContinuePressed()),
]);

final withdrawReviewState = applyWithdraw(withdrawRecipientState, [
  WithdrawRecipientPicked(withdrawBankRecipient),
  WithdrawOrderChanged(OrderCreateAnswered(1, Ok(withdrawOrder()))),
]);
