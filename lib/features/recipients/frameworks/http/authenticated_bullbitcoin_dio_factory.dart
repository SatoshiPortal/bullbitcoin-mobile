import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/features/recipients/frameworks/http/bullbitcoin_api_dio_factory.dart';
import 'package:bb_mobile/features/recipients/frameworks/http/bullbitcoin_api_key_provider.dart';
import 'package:dio/dio.dart';

class AuthenticatedBullBitcoinDioFactory {
  static Dio create({
    required bool isTestnet,
    required BullbitcoinApiKeyProvider apiKeyProvider,
  }) {
    final dio = BullBitcoinApiDioFactory.create(isTestnet: isTestnet);

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final apiKey = await apiKeyProvider.getApiKey(isTestnet: isTestnet);

          if (apiKey == null) {
            return handler.reject(
              DioException(
                requestOptions: options,
                error: ApiKeyException(
                  'API key not found. Please login to your Bull Bitcoin account.',
                ),
              ),
            );
          }

          options.headers['X-API-Key'] = apiKey;
          handler.next(options);
        },
      ),
    );

    return dio;
  }
}
