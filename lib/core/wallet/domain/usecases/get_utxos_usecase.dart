import 'package:bb_mobile/core/wallet/domain/entities/transaction_output.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/utxo_repository.dart';

class GetUtxosUsecase {
  final UtxoRepository _utxoRepository;

  GetUtxosUsecase({
    required UtxoRepository utxoRepository,
  }) : _utxoRepository = utxoRepository;

  Future<List<TransactionOutput>> execute({
    required String walletId,
  }) async {
    try {
      final utxos = await _utxoRepository.getUtxos(
        walletId: walletId,
      );
      return utxos;
    } catch (e) {
      throw GetUtxosUsecaseException(e.toString());
    }
  }
}

class GetUtxosUsecaseException implements Exception {
  final String message;

  GetUtxosUsecaseException(this.message);
}
