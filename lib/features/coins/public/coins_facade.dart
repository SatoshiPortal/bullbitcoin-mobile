export '../domain/usecases/get_wallet_utxos_usecase.dart';
import '../domain/labeled_wallet_utxo_repository.dart';
import '../domain/wallet_utxo.dart';

export '../domain/wallet_utxo.dart'
    show WalletUtxo, BitcoinWalletUtxo, LiquidWalletUtxo, $WalletUtxoCopyWith;
export '../domain/labeled_wallet_utxo_repository.dart'
    show LabeledWalletUtxoRepository;

/// Label-enriched coin projections for consuming features.
class CoinsFacade {
  final LabeledWalletUtxoRepository _repository;

  const CoinsFacade(this._repository);

  Future<List<WalletUtxo>> getWalletUtxos({required String walletId}) =>
      _repository.getWalletUtxos(walletId: walletId);
}
