import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/repositories/exchange_access_repository.dart';
import 'package:primitives/primitives.dart';

class ExpireExchangeSessionUsecase {
  const ExpireExchangeSessionUsecase(this._repository);
  final ExchangeAccessRepository _repository;
  Future<Result<void, ExchangeFailure>> execute({
    required int epoch,
    required bool isTestnet,
  }) => _repository.expireSession(epoch: epoch, isTestnet: isTestnet);
}
