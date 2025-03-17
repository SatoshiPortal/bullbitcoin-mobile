// ignore_for_file: constant_identifier_names

import 'dart:math';

import 'package:bb_mobile/_model/currency.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:dio/dio.dart';

const INR_USD = 91;
const CRC_USD = 540;

class BullBitcoinAPI {
  BullBitcoinAPI(this.http);

  final Dio http;

  Future<(Currency?, Err?)> getExchangeRate({
    required String toCurrency,
  }) async {
    try {
      final url = 'https://$exchangeapi';
      final resp = await http.post(
        url,
        data: {
          'id': 1,
          'jsonrpc': '2.0',
          'method': 'getRate',
          'params': {
            'element': {
              'fromCurrency': 'BTC',
              'toCurrency': toCurrency.toUpperCase() == 'INR' ||
                      toCurrency.toUpperCase() == 'CRC'
                  ? 'USD'
                  : toCurrency.toUpperCase(),
            }
          },
        },
      );

      if (resp.statusCode == null || resp.statusCode != 200) {
        throw 'Error Occured.';
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

      final currency = Currency(
        name: toCurrency,
        shortName: toCurrency,
        price: toCurrency.toUpperCase() == 'INR'
            ? double.parse((rateDouble * INR_USD).toStringAsFixed(2))
            : toCurrency.toUpperCase() == 'CRC'
                ? double.parse((rateDouble * CRC_USD).toStringAsFixed(2))
                : double.parse(rateDouble.toStringAsFixed(2)),
      );

      return (currency, null);
    } catch (e) {
      return (null, Err(e.toString(), expected: true));
    }
  }
}



// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 


// class CoinGecko {
//   Future<Result<List<Currency>>> getExchangeRate() async {
//     try {
//       final resp = await Dio().get(
//         'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd%2Ccad%2Cinr%2Ceur',
//       );

//       if (resp.statusCode == null || resp.statusCode != 200) {
//         throw 'Error Occured.';
//       }

//       final data = resp.data as Map<String, dynamic>;
//       final bitcoin = data['bitcoin'] as Map<String, dynamic>;

//       final List<Currency> currencies = [];

//       // for (var key in bitcoin.keys) {
//       //   currencies.add(Currency(name: key, price: bitcoin[key] as double));
//       // }

//       bitcoin.forEach((key, value) {
//         double price;
//         try {
//           price = value as double;
//         } catch (e) {
//           price = double.parse(value.toString());
//         }
//         currencies.add(
//           Currency(
//             name: key,
//             shortName: key,
//             price: price,
//           ),
//         );
//       });

//       return Result(value: currencies);
//     } catch (e) {
//       return Result(error: e.toString());
//     }
//   }
// }
