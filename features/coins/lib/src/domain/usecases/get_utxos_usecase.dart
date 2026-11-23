import 'package:primitives/primitives.dart';
import 'package:coins/src/domain/wallet_utxo.dart';
import 'package:coins/src/domain/repositories/wallet_utxo_repository.dart';
import 'package:coins/src/domain/coins_failure.dart';

/// Loads the current wallet coins with confirmations, freezes and labels.
class GetUtxosUsecase {
  GetUtxosUsecase({required this._repository});

  final WalletUtxoRepository _repository;

  Future<Result<List<WalletUtxo>, CoinsFailure>> execute({
    required String walletId,
  }) => _repository.getWalletUtxos(walletId: walletId);
}
