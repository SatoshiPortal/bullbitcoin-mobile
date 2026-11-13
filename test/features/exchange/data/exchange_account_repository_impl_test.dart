import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/features/exchange/data/exchange_account_repository_impl.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Datasource extends Mock implements BullbitcoinApiDatasource {}

void main() {
  late _Datasource datasource;
  late ExchangeAccountRepositoryImpl repository;

  setUp(() {
    datasource = _Datasource();
    repository = ExchangeAccountRepositoryImpl(datasource);
  });

  DioException responseError(int status) {
    final request = RequestOptions(path: '/');
    return DioException(
      requestOptions: request,
      response: Response<void>(requestOptions: request, statusCode: status),
      type: DioExceptionType.badResponse,
    );
  }

  test('401 is a definitive refusal; 403 and 503 retain the session', () async {
    for (final status in [401, 403, 503]) {
      when(datasource.getUserSummary).thenThrow(responseError(status));
      final result = await repository.getAccount();
      expect(result, isA<Err<UserSummary, ExchangeFailure>>());
      final failure = (result as Err<UserSummary, ExchangeFailure>).failure;
      expect(
        failure,
        status == 401
            ? isA<ExchangeNotAuthenticatedFailure>()
            : isA<ExchangeAccountUnavailableFailure>(),
      );
      expect(failure.logMessage, isNull);
    }
  });

  test(
    'timeouts and unreadable local credentials do not look like logout',
    () async {
      final request = RequestOptions(path: '/');
      when(datasource.getUserSummary).thenThrow(
        DioException(
          requestOptions: request,
          type: DioExceptionType.connectionTimeout,
        ),
      );
      expect(
        (await repository.getAccount() as Err<UserSummary, ExchangeFailure>)
            .failure,
        isA<ExchangeNetworkFailure>(),
      );
      when(datasource.getUserSummary).thenThrow(
        DioException(
          requestOptions: request,
          error: const ExchangeAuthenticationException(
            ExchangeApiKeyReadFailure(),
          ),
        ),
      );
      expect(
        (await repository.getAccount() as Err<UserSummary, ExchangeFailure>)
            .failure,
        isA<ExchangeAccountUnavailableFailure>(),
      );
    },
  );
}
