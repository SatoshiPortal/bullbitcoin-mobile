import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const apiKey =
      'bbak-de07e93fb1c55947c0962278fcad7e82d8c3fc45d63d7757601a47f782518147';
  final dio = Dio(BaseOptions(baseUrl: 'https://api05.bullbitcoin.dev'));
  final datasource = BullbitcoinApiDatasource(bullbitcoinApiHttpClient: dio);

  test('getUserSummary returns UserSummaryModel', () async {
    final result = await datasource.getUserSummary(apiKey);
    expect(result?.email, 'k147@k147.k147');
  });
}
