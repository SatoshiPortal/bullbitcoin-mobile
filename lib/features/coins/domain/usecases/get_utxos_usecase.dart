import 'package:coins/coins.dart';
import 'package:primitives/primitives.dart';

class GetUtxosUsecase {
  final Coins _coins;

  const GetUtxosUsecase(this._coins);

  Future<Result<List<WalletUtxo>, CoinsFailure>> execute({
    required String walletId,
  }) => _coins.coins(walletId);
}
