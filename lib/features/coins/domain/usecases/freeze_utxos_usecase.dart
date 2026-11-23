import 'package:coins/coins.dart';
import 'package:primitives/primitives.dart';

class FreezeUtxosUsecase {
  final Coins _coins;

  const FreezeUtxosUsecase(this._coins);

  Future<Result<void, CoinsFailure>> execute({
    required String walletId,
    required List<Outpoint> outpoints,
  }) => _coins.freeze(walletId, outpoints);
}
