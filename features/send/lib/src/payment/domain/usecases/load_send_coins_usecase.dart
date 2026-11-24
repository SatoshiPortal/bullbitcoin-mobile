import 'package:coins/coins.dart';
import 'package:primitives/primitives.dart';

import '../send_failure.dart';

class LoadSendCoinsUsecase {
  final Coins _coins;

  const LoadSendCoinsUsecase(this._coins);

  Future<Result<List<WalletUtxo>, SendFailure>> execute(
    String walletId,
  ) async =>
      (await _coins.load(walletId: walletId))
          .mapErr((failure) => SendUnexpectedFailure(failure.logMessage));
}
