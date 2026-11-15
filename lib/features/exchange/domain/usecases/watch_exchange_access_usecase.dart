import '../exchange_access.dart';
import '../repositories/exchange_access_repository.dart';

class WatchExchangeAccessUsecase {
  const WatchExchangeAccessUsecase(this._repository);
  final ExchangeAccessRepository _repository;
  ExchangeAccess get current => _repository.current;
  Stream<ExchangeAccess> execute() => _repository.watch();
}
