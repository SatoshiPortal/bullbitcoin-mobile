import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:flutter/widgets.dart';

class CheckPayjoinRelayHealthUsecase {
  final PayjoinRepository _repository;

  const CheckPayjoinRelayHealthUsecase({
    required PayjoinRepository payjoinRepository,
  }) : _repository = payjoinRepository;

  Future<bool> execute() async {
    try {
      return await _repository.checkOhttpRelayHealth();
    } catch (e) {
      debugPrint('Error checking Payjoin relay health: $e');
      return false;
    }
  }
}
