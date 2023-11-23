import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Test Exchange rate API', () {
    late Dio dio;
    late BullBitcoinAPI api;

    setUpAll(() async {
      await dotenv.load(isOptional: true);
      dio = Dio();
      api = BullBitcoinAPI(dio);
    });

    test('Successfully load CAD currency data', () async {
      final (cad, err) = await api.getExchangeRate(toCurrency: 'CAD');
      expect(err, isNull);
      expect(cad, isNotNull);
    });

    test('Error when currency param is invalid', () async {
      final (cad, err) = await api.getExchangeRate(toCurrency: 'INVALID');
      expect(err, isNotNull);
      expect(cad, isNull);
    });
  });
}
