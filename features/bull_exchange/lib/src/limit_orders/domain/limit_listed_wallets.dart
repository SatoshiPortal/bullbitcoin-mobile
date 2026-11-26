import 'package:secrets/secrets.dart';

/// The app wallets the limit-order flow listed last, by id: a receive
/// address is only ever read from a wallet the latest context load listed.
/// One per flow, refilled by every context load and read by the receive
/// address.
final class LimitListedWallets {
  final _byId = <String, WalletRegistration>{};

  /// Replaces the listed wallets with [wallets].
  void replaceAll(Iterable<WalletRegistration> wallets) => _byId
    ..clear()
    ..addEntries(wallets.map((w) => MapEntry(w.id, w)));

  WalletRegistration? operator [](String walletId) => _byId[walletId];
}
