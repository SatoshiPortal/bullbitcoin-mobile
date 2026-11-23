import 'package:primitives/primitives.dart';
import 'package:coins/src/domain/repositories/wallet_utxo_repository.dart';
import 'package:coins/src/domain/coins_failure.dart';

/// Freezes the given outpoints for a wallet.
class FreezeUtxosUsecase {
  FreezeUtxosUsecase({required this._walletUtxoRepository});

  final WalletUtxoRepository _walletUtxoRepository;

  Future<Result<void, CoinsFailure>> execute({
    required String walletId,
    required List<Outpoint> outpoints,
  }) => _walletUtxoRepository.freezeUtxos(
    walletId: walletId,
    outpoints: outpoints,
  );
}
