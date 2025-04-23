import 'package:bb_mobile/core/exchange/data/models/user_summary_model.dart';
import 'package:dio/dio.dart';

class BullBitcoinUserDatasource {
  final Dio _http;

  BullBitcoinUserDatasource({
    required Dio bullBitcoinHttpClient,
  }) : _http = bullBitcoinHttpClient;
  Future<UserSummaryModel?> getUserSummary(String apiKey) async {
    try {
      final resp = await _http.post(
        "/ak/api-users",
        data: {
          'id': 1,
          'jsonrpc': '2.0',
          'method': 'getUserSummary',
          'params': {},
        },
        options: Options(
          headers: {
            // 'Authorization': 'Bearer $apiKey',
            'X-API-Key': apiKey,
          },
        ),
      );

      if (resp.statusCode == null || resp.statusCode != 200) {
        throw 'Unable to fetch user summary from Bull Bitcoin API';
      }

      final userSummary = UserSummaryModel.fromJson(
        resp.data['result'] as Map<String, dynamic>,
      );

      return userSummary;
    } catch (e) {
      rethrow;
    }
  }
}
