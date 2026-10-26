import 'dart:async';

import 'package:bull_pricer/src/data/models/price_response_model.dart';
import 'package:bull_pricer/src/domain/entities/supported_currency.dart';
import 'package:dio/dio.dart';
import 'package:primitives/primitives.dart';

final class PricerApiDatasource {
  static const _pricePath = '/public/price';

  static const _mainnetBaseUrl = 'https://api.bullbitcoin.com';
  static const _testnetBaseUrl = 'https://api05.bullbitcoin.dev';

  static const _timeout = Duration(seconds: 10);

  const PricerApiDatasource();

  /// Public price: no auth needed.
  Future<PriceResponseModel> indexPrice(
    BitcoinNetwork network,
    SupportedCurrency currency,
  ) async {
    final dio = _clientHttp(network);
    final params = {'fromCurrency': 'BTC', 'toCurrency': currency.code};
    final body = await _request(dio, 'getRate', params);
    return _priceFrom(body);
  }

  Dio _clientHttp(BitcoinNetwork network) {
    return Dio(
      BaseOptions(
        baseUrl: _baseUrl(network),
        connectTimeout: _timeout,
        sendTimeout: _timeout,
        receiveTimeout: _timeout,
        contentType: Headers.jsonContentType,
      ),
    );
  }

  static String _baseUrl(BitcoinNetwork network) => switch (network) {
    BitcoinNetwork.mainnet => _mainnetBaseUrl,
    BitcoinNetwork.testnet => _testnetBaseUrl,
    BitcoinNetwork.signet ||
    BitcoinNetwork.regtest => throw PricerUnsupportedNetworkException(network),
  };

  Future<Object?> _request(
    Dio clientHttp,
    String method,
    Map<String, String> params,
  ) async {
    final response = await clientHttp
        .post<Object?>(
          _pricePath,
          data: {
            'id': 1,
            'jsonrpc': '2.0',
            'method': method,
            'params': {'element': params},
          },
        )
        .timeout(_timeout);
    return response.data;
  }

  PriceResponseModel _priceFrom(Object? body) => switch (body) {
    {'error': final Object error} => throw FormatException(
      'Price API error: $error',
      body,
    ),
    {'result': {'element': final Map<String, dynamic> element}} =>
      PriceResponseModel.fromJson(element),
    _ => throw FormatException('No price in the answer', body),
  };
}

/// The price service only exists for mainnet and testnet: the request was
/// never sent.
final class PricerUnsupportedNetworkException implements Exception {
  final BitcoinNetwork network;

  const PricerUnsupportedNetworkException(this.network);
}
