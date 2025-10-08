import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';

class GetPayjoinByIdUsecase {
  final PayjoinRepository _payjoinRepository;

  GetPayjoinByIdUsecase({required PayjoinRepository payjoinRepository})
    : _payjoinRepository = payjoinRepository;

  Future<Payjoin> execute(String payjoinId) async {
    try {
      final payjoin = await _payjoinRepository.getPayjoinById(payjoinId);
      if (payjoin == null) {
        throw GetPayjoinByIdException('Payjoin not found');
      }
      return payjoin;
    } catch (e) {
      throw GetPayjoinByIdException('$e');
    }
  }
}

class GetPayjoinByIdException extends BullException {
  GetPayjoinByIdException(super.message);
}
