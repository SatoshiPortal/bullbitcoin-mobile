import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:dio/dio.dart';

/// Attaches authentication without replacing the client's existing options.
void addExchangeAuthentication(Dio dio, ReadExchangeApiKey readApiKey) {
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // A RequestOptions object can be retried; never reuse its old key.
        options.headers.removeWhere(
          (name, _) => name.toLowerCase() == 'x-api-key',
        );
        final result = await readApiKey();
        switch (result) {
          case Ok(value: final String key):
            options.headers['X-API-Key'] = key;
            handler.next(options);
          case Ok():
            handler.reject(
              DioException(
                requestOptions: options,
                error: const ExchangeAuthenticationException(),
              ),
            );
          case Err(:final failure):
            handler.reject(
              DioException(
                requestOptions: options,
                error: ExchangeAuthenticationException(failure),
              ),
            );
        }
      },
    ),
  );
}
