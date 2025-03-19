import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';

abstract class ExchangeDatasource {
  Future<List<String>> getAvailableCurrencies();
  Future<Decimal> getBitcoinPrice(String currencyCode);
}

class BullBitcoinExchangeDatasourceImpl implements ExchangeDatasource {
  static const _pricePath = 'price';
  static const _inr_usd = 91;
  static const _crc_usd = 540;
  final Dio _http;

  BullBitcoinExchangeDatasourceImpl({
    Dio? bullBitcoinHttpClient,
  }) : _http = bullBitcoinHttpClient ??
            Dio(
              BaseOptions(
                  // baseUrl: 'https://api.bullbitcoin.com/public/price',
                  ),
            );

  @override
  Future<List<String>> getAvailableCurrencies() async {
    // TODO: implement getAvailableCurrencies
    throw UnimplementedError();
  }

  @override
  Future<Decimal> getBitcoinPrice(String currencyCode) async {
    try {
      final resp = await _http.post(
        'https://api.bullbitcoin.com/public/price',
        // _pricePath,
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
      final rateDouble = price / pow(10, precision);

      final rate = Decimal.fromBigInt(BigInt.from(rateDouble));
      // .tryParse(result['indexPrice'] as String);

      // if (rate == null) {
      //   throw 'Unable to parse exchange rate from Bull Bitcoin Exchange API';
      // }

      return rate;
    } catch (e) {
      // TODO: Use custom error class
      rethrow;
    }
  }
}
