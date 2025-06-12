import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class CheckPayjoinRelayHealthUsecase {
  final PayjoinRepository _repository;

  const CheckPayjoinRelayHealthUsecase({
    required PayjoinRepository payjoinRepository,
  }) : _repository = payjoinRepository;

  Future<bool> execute() async {
    try {
      return await _repository.checkOhttpRelayHealth();
    } catch (e) {
      log.warning('Error checking Payjoin relay health: $e');
      return false;
    }
  }
}
