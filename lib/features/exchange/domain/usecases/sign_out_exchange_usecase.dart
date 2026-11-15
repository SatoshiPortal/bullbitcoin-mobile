import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/repositories/exchange_access_repository.dart';
import 'package:primitives/primitives.dart';

class SignOutExchangeUsecase {
  const SignOutExchangeUsecase(this._repository);
  final ExchangeAccessRepository _repository;
  Future<Result<void, ExchangeFailure>> execute() => _repository.signOut();
}
