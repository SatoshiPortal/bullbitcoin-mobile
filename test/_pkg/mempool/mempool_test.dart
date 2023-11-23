import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Load Fees from default mempool api', () {
    late Dio dio;
    late MempoolAPI api;

    setUpAll(() async {
      await dotenv.load(isOptional: true);
      dio = Dio();
      api = MempoolAPI(dio);
    });

    test('Successfully load mainet fees data', () async {
      final (fees, err) = await api.getFees(false);
      expect(err, isNull);
      expect(fees, isNotNull);
      expect(fees!.length, 5);
    });

    test('Successfully load testnet fees data', () async {
      final (fees, err) = await api.getFees(true);
      expect(err, isNull);
      expect(fees, isNotNull);
      expect(fees!.length, 5);
    });
  });
}
