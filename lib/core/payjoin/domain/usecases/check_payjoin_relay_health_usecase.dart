import 'package:bb_mobile/core/payjoin/data/repository/payjoin_repository_impl.dart';
import 'package:flutter/widgets.dart';

class CheckPayjoinRelayHealthUsecase {
  final PayjoinRepository _repository;

  const CheckPayjoinRelayHealthUsecase({
    required PayjoinRepository payjoinRepository,
  }) : _repository = payjoinRepository;

  Future<bool> execute() async {
    try {
      _repository.checkOhttpRelayHealth();
      return true;
    } catch (e) {
      debugPrint('Error checking Payjoin relay health: $e');
      return false;
    }
  }
}
