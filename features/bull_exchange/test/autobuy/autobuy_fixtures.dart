import 'package:bull_exchange/src/autobuy/domain/autobuy_flow.dart';
import 'package:exchange/exchange.dart';

const autoBuySession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'a',
);
const autoBuyOtherSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 2,
  sessionId: 'b',
);

UserSummary autoBuySummary({
  bool active = false,
  List<String> groups = const ['KYC_IDENTITY_VERIFIED'],
}) => UserSummary(
  userNumber: 1,
  groups: groups,
  profile: const UserProfile(firstName: 'Satoshi', lastName: 'Nakamoto'),
  email: 'satoshi@example.com',
  balances: const [UserBalance(amount: 500, currencyCode: 'CAD')],
  language: 'EN',
  currency: 'CAD',
  dca: const UserDca(isActive: false),
  autoBuy: UserAutoBuy(
    isActive: active,
    addresses: const UserAutoBuyAddresses(),
  ),
  emailNotificationsEnabled: false,
);

AutoBuyContext autoBuyContext({
  bool active = false,
  List<String> groups = const ['KYC_IDENTITY_VERIFIED'],
  List<UnknownWrite> entries = const [],
}) => AutoBuyContext(autoBuySummary(active: active, groups: groups), entries);

const autoBuyWallets = DefaultWallets(
  bitcoin: DefaultWallet(
    recipientId: 'r-btc',
    walletType: BtcNetwork.bitcoin,
    address: 'bc1qauto',
  ),
);
