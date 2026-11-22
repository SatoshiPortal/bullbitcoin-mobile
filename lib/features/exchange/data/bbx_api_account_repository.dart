import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/features/exchange/data/bbx_api_user_summary_mapper.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/repositories/exchange_account_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:primitives/primitives.dart' show Err, Ok, Result;

/// [ExchangeAccountRepository] through the `bbx_api` package.
class BbxApiAccountRepository implements ExchangeAccountRepository {
  const BbxApiAccountRepository(this._api);

  final bbx.Bbx _api;

  @override
  Future<Result<UserSummary, ExchangeFailure>> getAccount() async {
    try {
      final result = await _api.users.getUserSummary();
      return switch (result) {
        Ok(value: final summary?) => Ok(userSummaryFromBbxApi(summary)),
        Ok() => const Err(ExchangeAccountUnavailableFailure()),
        Err(failure: bbx.BbxMissingCredentialFailure()) => const Err(
          ExchangeNotAuthenticatedFailure(),
        ),
        Err(failure: bbx.BbxHttpFailure(status: 401)) => const Err(
          ExchangeSessionRejectedFailure(),
        ),
        Err(failure: bbx.BbxTimeoutFailure() || bbx.BbxConnectionFailure()) =>
          const Err(ExchangeNetworkFailure()),
        Err() => const Err(ExchangeAccountUnavailableFailure()),
      };
    } on Exception {
      return const Err(ExchangeAccountUnavailableFailure());
    }
  }
}
