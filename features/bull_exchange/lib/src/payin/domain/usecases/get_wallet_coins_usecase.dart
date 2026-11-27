import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show Coin;

/// The coins of a wallet the user may pick for the payin;
/// [ExchangeWalletCoinsUnavailableFailure] when the wallet can't tell (not a
/// wallet this device signs for, or unreadable).
class GetWalletCoinsUsecase {
  final Future<Result<List<Coin>, ExchangeWalletCoinsUnavailableFailure>>
  Function(String walletId)
  _coins;

  const GetWalletCoinsUsecase(this._coins);

  Future<Result<List<Coin>, ExchangeWalletCoinsUnavailableFailure>> execute(
    String walletId,
  ) => _coins(walletId);
}
