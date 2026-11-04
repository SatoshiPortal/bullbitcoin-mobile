import 'package:primitives/primitives.dart' show BullException;
import 'package:bb_mobile/features/coins/public/coins_facade.dart';

class GetWalletUtxosUsecase {
  final LabeledWalletUtxoRepository _utxoRepository;

  GetWalletUtxosUsecase({required this._utxoRepository});

  Future<List<WalletUtxo>> execute({required String walletId}) async {
    try {
      final utxos = await _utxoRepository.getWalletUtxos(walletId: walletId);
      return utxos;
    } catch (e) {
      throw GetUtxosUsecaseException(e.toString());
    }
  }
}

class GetUtxosUsecaseException extends BullException {
  GetUtxosUsecaseException(super.message);
}
