import 'package:secrets/secrets.dart';

/// The payout wallets the buy flow listed, by id: a receive address is only
/// ever read from a wallet the flow listed. One per flow, filled by the
/// context load and read by the receive address.
final class BuyListedWallets {
  final _byId = <String, WalletRegistration>{};

  void add(WalletRegistration wallet) => _byId[wallet.id] = wallet;

  WalletRegistration? operator [](String walletId) => _byId[walletId];
}
