import 'package:bb_mobile/core/data/datasources/exchange_data_source.dart';
import 'package:bb_mobile/core/data/models/fiat_currency_model.dart';
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';

class BullBitcoinExchangeDataSourceImpl implements ExchangeDataSource {
  static const _pricePath = 'price';
  static const _inr_usd = 88;
  static const _crc_usd = 540;
  final Dio _http;

  BullBitcoinExchangeDataSourceImpl({
    Dio? bullBitcoinHttpClient,
  }) : _http = bullBitcoinHttpClient ??
            Dio(
              BaseOptions(baseUrl: 'https://api.bullbitcoin.com'),
            );

  @override
  Future<List<FiatCurrencyModel>> getAvailableCurrencies() async {
    // TODO: implement getAvailableCurrencies
    throw UnimplementedError();
  }

  @override
  Future<Decimal> getBitcoinPrice(String currencyCode) async {
    try {
      final resp = await _http.post(
        _pricePath,
        // TODO: Create a model for this request data
        data: {
          'id': 0,
          'jsonrpc': '2.0',
          'method': 'getRate',
          'params': {
            'from': 'BTC',
            'to': currencyCode.toUpperCase() == 'INR' ||
                    currencyCode.toUpperCase() == 'CRC'
                ? 'USD'
                : currencyCode.toUpperCase(),
          },
        },
      );

      if (resp.statusCode == null || resp.statusCode != 200) {
        throw 'Unable to fetch exchange rate from Bull Bitcoin Exchange API';
      }
      final data = resp.data as Map<String, dynamic>;
      final result = data['result'] as Map<String, dynamic>;

      final rate = Decimal.tryParse(result['indexPrice'] as String);

      if (rate == null) {
        throw 'Unable to parse exchange rate from Bull Bitcoin Exchange API';
      }

      return rate;
    } catch (e) {
      // TODO: Use custom error class
      rethrow;
    }
  }
}
