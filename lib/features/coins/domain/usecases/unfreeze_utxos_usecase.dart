import 'package:coins/coins.dart';
import 'package:primitives/primitives.dart';

class UnfreezeUtxosUsecase {
  final Coins _coins;

  const UnfreezeUtxosUsecase(this._coins);

  Future<Result<void, CoinsFailure>> execute({
    required String walletId,
    required List<Outpoint> outpoints,
  }) => _coins.unfreeze(outpoints);
}
