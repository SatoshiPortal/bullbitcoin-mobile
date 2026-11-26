import 'package:sync/sync.dart' show Coin;

/// The coins of a wallet the user may pick for the payin; null when the
/// wallet can't tell (not a wallet this device signs for, or unreadable).
class GetWalletCoinsUsecase {
  final Future<List<Coin>?> Function(String walletId) _coins;

  const GetWalletCoinsUsecase(this._coins);

  Future<List<Coin>?> execute(String walletId) => _coins(walletId);
}
