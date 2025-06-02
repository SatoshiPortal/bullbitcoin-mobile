import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bull_bitcoin_user_datasource.dart';

void main() {
  const apiKey =
      'bbak-c668c543468f722d83213a3d80a662b36f22fd53f8f8501a75845c92107c2ad9';
  final dio = Dio(BaseOptions(baseUrl: 'https://api05.bullbitcoin.dev'));
  final datasource = BullBitcoinUserDatasource(bullBitcoinHttpClient: dio);

  test('getUserSummary returns UserSummaryModel', () async {
    final result = await datasource.getUserSummary(apiKey);
    expect(result?.email, 'apiKeyUser@test.com');
  });
}
