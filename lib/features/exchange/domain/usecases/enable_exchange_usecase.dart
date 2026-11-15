import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/repositories/exchange_access_repository.dart';
import 'package:primitives/primitives.dart';

class EnableExchangeUsecase {
  const EnableExchangeUsecase(this._repository);
  final ExchangeAccessRepository _repository;
  Future<Result<void, ExchangeFailure>> execute({
    bool onlyIfUnset = false,
    bool choice = true,
    bool forSupport = false,
  }) => _repository.enable(
    onlyIfUnset: onlyIfUnset,
    choice: choice,
    forSupport: forSupport,
  );
}
