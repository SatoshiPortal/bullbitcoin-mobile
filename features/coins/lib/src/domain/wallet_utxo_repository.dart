import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'coins_failure.dart';
import 'wallet_utxo.dart';

abstract interface class WalletUtxoRepository {
  @useResult
  Future<Result<List<WalletUtxo>, CoinsFailure>> coins(String walletId);

  @useResult
  Future<Result<void, CoinsFailure>> freeze(
    String walletId,
    List<Outpoint> outpoints,
  );

  @useResult
  Future<Result<void, CoinsFailure>> unfreeze(List<Outpoint> outpoints);
}
