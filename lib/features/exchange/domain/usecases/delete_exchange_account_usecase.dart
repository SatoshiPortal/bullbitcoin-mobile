import 'package:primitives/primitives.dart';
import '../exchange_access.dart';
import '../exchange_failure.dart';
import '../repositories/exchange_access_repository.dart';
import 'request_exchange_account_deletion_usecase.dart';
import 'sign_out_exchange_usecase.dart';

enum ExchangeAccountDeletionOutcome { completed, stale }

class DeleteExchangeAccountUsecase {
  const DeleteExchangeAccountUsecase(
    this._request,
    this._signOut,
    this._access,
  );
  final RequestExchangeAccountDeletionUsecase _request;
  final SignOutExchangeUsecase _signOut;
  final ExchangeAccessRepository _access;

  Future<Result<ExchangeAccountDeletionOutcome, ExchangeFailure>>
  execute() async {
    if (_access.current case ExchangeAccessEnabled(
      session: ExchangeAccessSession.signedIn,
    )) {
      final epoch = _access.epoch;
      final result = await _request.execute();
      if (_access.epoch != epoch) {
        return const Ok(ExchangeAccountDeletionOutcome.stale);
      }
      if (result case Err(:final failure)) return Err(failure);
      return (await _signOut.execute()).map(
        (_) => ExchangeAccountDeletionOutcome.completed,
      );
    }
    return const Err(ExchangeNotAuthenticatedFailure());
  }
}
