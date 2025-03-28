import 'dart:math';

import 'package:dio/dio.dart';

class BitcoinPriceDatasource {
  final Dio _http;
  final _pricePath = '/public/price';

  BitcoinPriceDatasource({
    required Dio bullBitcoinHttpClient,
  }) : _http = bullBitcoinHttpClient;

  Future<List<String>> get availableCurrencies async {
    // TODO: fetch the actual list of currencies from the api
    return ['USD', 'CAD', 'INR', 'CRC', 'EUR'];
  }

  Future<double> getPrice(String currencyCode) async {
    try {
      final resp = await _http.post(
        _pricePath,
        // TODO: Create a model for this request data
        data: {
          'id': 1,
          'jsonrpc': '2.0',
          'method': 'getRate',
          'params': {
            'element': {
              'fromCurrency': 'BTC',
              'toCurrency': currencyCode.toUpperCase() == 'INR' ||
                      currencyCode.toUpperCase() == 'CRC'
                  ? 'USD'
                  : currencyCode.toUpperCase(),
            },
            // 'from': 'BTC',
            // 'to': currencyCode.toUpperCase() == 'INR' ||
            //         currencyCode.toUpperCase() == 'CRC'
            //     ? 'USD'
            //     : currencyCode.toUpperCase(),
          },
        },
      );

      if (resp.statusCode == null || resp.statusCode != 200) {
        throw 'Unable to fetch exchange rate from Bull Bitcoin Exchange API';
      }
      // Parse the response data correctly
      final data = resp.data as Map<String, dynamic>;
      final result = data['result'] as Map<String, dynamic>;
      final element = result['element'] as Map<String, dynamic>;

      // Extract price and precision
      final price = (element['indexPrice'] as num).toDouble();
      final precision = element['precision'] as int? ?? 2;

      // Convert price based on precision (e.g., if price is 11751892 and precision is 2, actual price is 117518.92)
      final rate = price / pow(10, precision);

      return rate;
    } catch (e) {
      rethrow;
    }
  }
}
