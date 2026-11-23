import 'package:exchange/setup.dart';
import 'package:exchange/exchange.dart';

class WatchExchangeAccessUsecase {
  const WatchExchangeAccessUsecase(this._repository);
  final ExchangeAccessLifecycle _repository;
  ExchangeAccess get current => _repository.current;
  Stream<ExchangeAccess> execute() => _repository.watch();
}
