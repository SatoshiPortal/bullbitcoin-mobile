import 'package:bb_mobile/core/utxo/domain/entities/utxo.dart';
import 'package:bb_mobile/core/utxo/domain/repositories/utxo_repository.dart';

class GetUtxosUsecase {
  final UtxoRepository _utxoRepository;

  GetUtxosUsecase({
    required UtxoRepository utxoRepository,
  }) : _utxoRepository = utxoRepository;

  Future<List<Utxo>> execute({
    required String origin,
  }) async {
    try {
      final utxos = await _utxoRepository.getUtxos(
        origin: origin,
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
