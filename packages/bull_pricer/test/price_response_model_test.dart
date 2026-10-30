import 'package:bull_pricer/src/data/models/price_response_model.dart';
import 'package:test/test.dart';

void main() {
  group('PriceResponseModel.fromJson', () {
    test('reads a getRate answer', () {
      // Real `element` from api05 `getRate`, BTC → CAD.
      final response = PriceResponseModel.fromJson({
        'fromCurrency': 'BTC',
        'toCurrency': 'CAD',
        'price': 11228945,
        'priceCurrency': 'CAD',
        'precision': 2,
        'indexPrice': 11424220,
        'createdAt': '2026-10-22T16:31:08.709Z',
      });

      expect(response.indexPrice(), closeTo(114242.20, 1e-9));
    });

    test('defaults to a precision of 2', () {
      final response = PriceResponseModel.fromJson({'indexPrice': 10000000});

      expect(response.indexPrice(), 100000);
    });

    test('rejects an answer without a usable price', () {
      final answers = <Map<String, dynamic>>[
        {},
        {'indexPrice': '11424220'},
        {'indexPrice': 0},
        {'indexPrice': -5},
        {'indexPrice': 11424220, 'precision': '2'},
      ];
      for (final answer in answers) {
        expect(
          () => PriceResponseModel.fromJson(answer),
          throwsFormatException,
          reason: '$answer',
        );
      }
    });
  });
}
