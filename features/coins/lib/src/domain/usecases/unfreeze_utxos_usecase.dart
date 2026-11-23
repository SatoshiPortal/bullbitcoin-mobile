import 'package:primitives/primitives.dart';
import 'package:coins/src/domain/repositories/wallet_utxo_repository.dart';
import 'package:coins/src/domain/coins_failure.dart';

/// Unfreezes the given outpoints. Persisted freezes are always user freezes
/// (system/payjoin locks are derived live, never stored), so unfreezing is safe
/// by construction.
class UnfreezeUtxosUsecase {
  UnfreezeUtxosUsecase({required this._walletUtxoRepository});

  final WalletUtxoRepository _walletUtxoRepository;

  Future<Result<void, CoinsFailure>> execute({
    required String walletId,
    required List<Outpoint> outpoints,
  }) => _walletUtxoRepository.unfreezeUtxos(
    walletId: walletId,
    outpoints: outpoints,
  );
}
