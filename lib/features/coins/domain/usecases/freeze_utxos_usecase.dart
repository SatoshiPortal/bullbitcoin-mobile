import 'package:primitives/primitives.dart' show Outpoint;
import 'package:bb_mobile/features/coins/domain/labeled_wallet_utxo_repository.dart';
import 'package:bb_mobile/features/coins/domain/coins_error.dart';

/// Freezes the given outpoints for a wallet (writes `origin = 'user'` rows via
/// the core repository). Maps any failure to [CoinsError.freezeFailed].
class FreezeUtxosUsecase {
  FreezeUtxosUsecase({required this._walletUtxoRepository});

  final LabeledWalletUtxoRepository _walletUtxoRepository;

  Future<void> execute({
    required String walletId,
    required List<Outpoint> outpoints,
  }) async {
    try {
      await _walletUtxoRepository.freezeUtxos(
        walletId: walletId,
        outpoints: outpoints,
      );
    } catch (_) {
      throw const CoinsError.freezeFailed();
    }
  }
}
