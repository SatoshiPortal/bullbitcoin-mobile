import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/exchange/data/mappers/user_summary_mapper.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/repositories/exchange_account_repository.dart';
import 'package:dio/dio.dart';

class ExchangeAccountRepositoryImpl implements ExchangeAccountRepository {
  const ExchangeAccountRepositoryImpl(this._datasource);

  final BullbitcoinApiDatasource _datasource;

  @override
  Future<Result<UserSummary, ExchangeFailure>> getAccount() async {
    try {
      final model = await _datasource.getUserSummary();
      return model == null
          ? const Err(ExchangeNotAuthenticatedFailure())
          : Ok(UserSummaryMapper.fromModelToEntity(model));
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
          return const Err(ExchangeNotAuthenticatedFailure());
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
