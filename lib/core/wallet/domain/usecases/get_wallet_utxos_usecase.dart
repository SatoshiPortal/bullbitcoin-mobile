import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';

class GetWalletUtxosUsecase {
  final WalletUtxoRepository _utxoRepository;

  GetWalletUtxosUsecase({required WalletUtxoRepository utxoRepository})
    : _utxoRepository = utxoRepository;

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
