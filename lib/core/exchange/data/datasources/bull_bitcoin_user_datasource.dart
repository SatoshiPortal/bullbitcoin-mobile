import 'package:dio/dio.dart';
import 'package:flutter/rendering.dart';

class BullBitcoinUserDatasource {
  final Dio _http;

  BullBitcoinUserDatasource({
    required Dio bullBitcoinHttpClient,
  }) : _http = bullBitcoinHttpClient;
  Future<void> getUserSummary(String apiKey) async {
    try {
      final resp = await _http.post(
        "/api-users",
        data: {
          'id': 1,
          'jsonrpc': '2.0',
          'method': 'getUserSummary',
          'params': {},
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
          },
        ),
      );

      if (resp.statusCode == null || resp.statusCode != 200) {
        throw 'Unable to fetch user summary from Bull Bitcoin API';
      }
      // Parse the response data correctly
      final data = resp.data as Map<String, dynamic>;
      debugPrint(data.toString());
    } catch (e) {
      rethrow;
    }
  }
}
