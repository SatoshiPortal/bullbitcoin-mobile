import 'package:bb_mobile/core/exchange/data/http/bullbitcoin_api_dio_factory.dart';
import 'package:bb_mobile/core/exchange/data/http/exchange_authentication_interceptor.dart';
import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:dio/dio.dart';

class AuthenticatedBullBitcoinDioFactory {
  static Dio create({
    required bool isTestnet,
    required ReadExchangeApiKey readApiKey,
  }) {
    final dio = BullBitcoinApiDioFactory.create(isTestnet: isTestnet);
    addExchangeAuthentication(dio, readApiKey);
    return dio;
  }
}
