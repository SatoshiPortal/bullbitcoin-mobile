import 'package:exchange/exchange.dart';

const dwSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'dw',
);

/// A session that is not the exchange's current one.
const dwOtherSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 2,
  sessionId: 'other',
);

const dwSaved = DefaultWallets(
  bitcoin: DefaultWallet(
    recipientId: 'r-1',
    walletType: BtcNetwork.bitcoin,
    address: 'bc1qsaved',
  ),
);
