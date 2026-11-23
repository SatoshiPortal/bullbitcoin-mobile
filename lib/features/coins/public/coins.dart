import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/coins_failure.dart';
import '../domain/wallet_utxo.dart';

export '../domain/coins_failure.dart';
export '../ui/coins_router.dart'
    show CoinsRoute, CoinsRouter, OpenSelectedCoinsFlow;

typedef CoinSummary = ({int count, BigInt frozenSat});

final class Coins {
  final Future<Result<List<WalletUtxo>, CoinsFailure>> Function({
    required String walletId,
  })
  _loadCoins;

  const Coins(this._loadCoins);

  @useResult
  Future<Result<CoinSummary, CoinsFailure>> summary(String walletId) async =>
      (await _loadCoins(walletId: walletId)).map(
        (utxos) => (
          count: utxos.length,
          frozenSat: utxos
              .where((utxo) => utxo.isFrozen)
              .fold(BigInt.zero, (sum, utxo) => sum + utxo.amountSat),
        ),
      );
}
