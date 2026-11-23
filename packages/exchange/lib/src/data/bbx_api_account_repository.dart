import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:primitives/primitives.dart' show Err, Ok, Result;

import '../domain/entities/user_summary.dart';
import '../domain/exchange_failure.dart';
import 'bbx_api_user_summary_mapper.dart';

final class BbxApiAccountRepository {
  final bbx.Bbx _api;

  const BbxApiAccountRepository(this._api);

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
