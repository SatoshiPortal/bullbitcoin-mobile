import 'package:exchange/setup.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

class ExpireExchangeSessionUsecase {
  const ExpireExchangeSessionUsecase(this._repository);
  final ExchangeAccessLifecycle _repository;
  Future<Result<void, ExchangeFailure>> execute({
    required int epoch,
    required bool isTestnet,
  }) => _repository.expireSession(epoch: epoch, isTestnet: isTestnet);
}
