import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';

class GetPayjoinByTxIdUsecase {
  final PayjoinRepository _payjoinRepository;

  GetPayjoinByTxIdUsecase(this._payjoinRepository);

  Future<Payjoin> execute(String txId) async {
    try {
      final payjoins = await _payjoinRepository.getPayjoinsByTxId(txId);
      if (payjoins.isEmpty) {
        throw GetPayjoinByTxIdException('Payjoin not found');
      }
      return payjoins.first;
    } on GetPayjoinByTxIdException {
      rethrow;
    } catch (e) {
      throw GetPayjoinByTxIdException('$e');
    }
  }
}

class GetPayjoinByTxIdException extends BullException {
  GetPayjoinByTxIdException(super.message);
}
