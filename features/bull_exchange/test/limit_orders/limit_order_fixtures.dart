import 'package:exchange/exchange.dart';

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
