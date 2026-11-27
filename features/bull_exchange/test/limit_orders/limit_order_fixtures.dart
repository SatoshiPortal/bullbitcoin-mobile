import 'package:bull_exchange/src/limit_orders/domain/limit_order_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';

UserSummary userSummary({
  List<UserBalance> balances = const [
    UserBalance(amount: 500, currencyCode: 'CAD'),
  ],
  String? currency = 'CAD',
}) => UserSummary(
  userNumber: 1,
  groups: const ['KYC_IDENTITY_VERIFIED'],
  profile: const UserProfile(firstName: 'Satoshi', lastName: 'Nakamoto'),
  email: 'satoshi@example.com',
  balances: balances,
  language: 'EN',
  currency: currency,
  dca: const UserDca(isActive: false),
  autoBuy: const UserAutoBuy(
    isActive: false,
    addresses: UserAutoBuyAddresses(),
  ),
  emailNotificationsEnabled: false,
);

LimitOrderRate limitOrderRate({double indexPrice = 100000}) => LimitOrderRate(
  currencyCode: 'CAD',
  indexPrice: indexPrice,
  userPrice: indexPrice,
);

LimitOrder limitOrder({
  String id = 'lo-1',
  LimitOrderStatus status = LimitOrderStatus.active,
}) => LimitOrder(
  id: id,
  number: 'LO-1',
  fiatAmount: 100,
  currencyCode: 'CAD',
  limitPrice: 90000,
  estimatedBtcAmount: 0.0011,
  status: status,
  createdAt: DateTime.utc(2026, 9, 1),
  expiresAt: DateTime.utc(2026, 12, 1),
  address: 'bc1qexample',
);

const limitSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'a',
);
const limitOtherSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 2,
  sessionId: 'b',
);

const limitBitcoinAddress = 'bc1qdefault';

DefaultWallets limitDefaultWallets() => const DefaultWallets(
  bitcoin: DefaultWallet(
    recipientId: 'r-btc',
    walletType: BtcNetwork.bitcoin,
    address: limitBitcoinAddress,
  ),
);

/// The create the real machine sends for a 200 CAD order at 80 000 to the
/// default bitcoin wallet, from a loaded context through Confirm.
ConfirmSend<LimitOrderRequest> limitCreateSend() {
  var next = (limitFlowStart(limitSession).state).next(
    LimitContextLoaded(
      1,
      Ok(
        LimitOrderContext(
          userSummary(),
          limitDefaultWallets(),
          const [],
          const [],
        ),
      ),
    ),
  );
  for (final event in <LimitFlowEvent>[
    const LimitContinuePressed(),
    LimitTargetRateArrived(ExchangeCatalog.cad, 1, Ok(limitOrderRate())),
    const LimitPriceTyped(80000),
    const LimitContinuePressed(),
    const LimitDestinationChanged(
      PickChose(
        DestinationOptionDefaultWallet(BtcNetwork.bitcoin, limitBitcoinAddress),
      ),
    ),
    const LimitContinuePressed(),
    const LimitAmountChanged(AmountTyped('200')),
    const LimitContinuePressed(),
    LimitReviewRateArrived(1, Ok(limitOrderRate())),
    const LimitConfirmPressed(),
  ]) {
    next = next.state.next(event);
  }
  return next.effects.whereType<LimitConfirmEffect>().single.effect
      as ConfirmSend<LimitOrderRequest>;
}
