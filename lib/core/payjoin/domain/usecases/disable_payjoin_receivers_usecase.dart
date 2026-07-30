import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';

class DisablePayjoinReceiversUsecase {
  final PayjoinRepository _payjoinRepository;

  DisablePayjoinReceiversUsecase({required this._payjoinRepository});

  Future<void> execute() => _payjoinRepository.disableReceivers();
}
