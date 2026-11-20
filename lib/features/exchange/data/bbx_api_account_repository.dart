import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/features/exchange/data/bbx_api_user_summary_mapper.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/repositories/exchange_account_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:dio/dio.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;

/// [ExchangeAccountRepository] through the `bbx_api` package.
class BbxApiAccountRepository implements ExchangeAccountRepository {
  const BbxApiAccountRepository(this._api);

  final bbx.BbxApiClient _api;

  @override
  Future<Result<UserSummary, ExchangeFailure>> getAccount() async {
    try {
      final summary = await _api.users.getUserSummary();
      return summary == null
          ? const Err(ExchangeAccountUnavailableFailure())
          : Ok(userSummaryFromBbxApi(summary));
    } on Exception catch (error) {
      if (error case DioException(
        error: final Error bug,
        stackTrace: final trace,
      )) {
        Error.throwWithStackTrace(bug, trace);
      }
      final localRefusal = exchangeAuthenticationException(error);
      if (localRefusal != null) {
        return localRefusal.isUnauthenticated
            ? const Err(ExchangeNotAuthenticatedFailure())
            : const Err(ExchangeAccountUnavailableFailure());
      }
      if (error is DioException) {
        if (error.response?.statusCode == 401) {
          return const Err(ExchangeSessionRejectedFailure());
        }
        if (switch (error.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.connectionError => true,
          _ => false,
        }) {
          return const Err(ExchangeNetworkFailure());
        }
      }
      return const Err(ExchangeAccountUnavailableFailure());
    }
  }
}
