import 'package:dio/dio.dart';

final class RecipientUpdateDatasource {
  const RecipientUpdateDatasource(
    this._mainnetApiClient,
    this._testnetApiClient,
  );

  static const _recipientsPath = '/ak/api-recipients';
  static const _apiVersion = '2.0.0';

  final Dio _mainnetApiClient;
  final Dio _testnetApiClient;

  Future<Map<String, dynamic>> update(
    Map<String, dynamic> element, {
    required bool isTestnet,
  }) async {
    final apiClient = isTestnet ? _testnetApiClient : _mainnetApiClient;
    final response = await apiClient.post(
      _recipientsPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'updateMyRecipient',
        'params': {'element': element},
      },
      options: Options(headers: {'x-api-version': _apiVersion}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update recipient');
    }
    final responseData = response.data;
    if (responseData is! Map) {
      throw const FormatException('Invalid recipient update response');
    }
    return Map<String, dynamic>.from(responseData);
  }
}
