import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/main.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  const apiKey =
      'bbak-c693dad066366dfb5c8d48af8f46cd4bb5b65f218fe31eb6ed2510cee80435f6';
  final dio = Dio(BaseOptions(baseUrl: ApiServiceConstants.bbApiUrl));
  final datasource = BullbitcoinApiDatasource(bullbitcoinApiHttpClient: dio);

  test('getUserSummary returns UserSummaryModel', () async {
    final result = await datasource.getUserSummary(apiKey);
    expect(result?.email, 'k147@k147.k147');
  });
}
