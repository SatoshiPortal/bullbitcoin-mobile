import 'package:exchange/setup.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

class ResolveExchangeAccessUsecase {
  const ResolveExchangeAccessUsecase(this._repository);
  final ExchangeAccessLifecycle _repository;
  Future<Result<void, ExchangeFailure>> execute() => _repository.resolve();
}
