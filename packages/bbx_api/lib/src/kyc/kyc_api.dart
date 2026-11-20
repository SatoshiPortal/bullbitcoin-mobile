import 'dart:convert';

import 'package:bbx_api/src/bbx_api_client.dart';
import 'package:bbx_api/src/bbx_api_exception.dart';

/// The `api-kyc` endpoint.
class KycApi {
  static const endpoint = '/ak/api-kyc';

  final BbxApiClient _client;

  KycApi(this._client);

  /// Uploads an identity document file as the `file` form field, with a
  /// `createMyKYCIDDocument` request for [idTypeCode] and [sourceDetail] in
  /// the `kycIDDocument` field.
  ///
  /// Throws a [BbxApiRpcException] when the response object, or its
  /// `result` object, carries an `error` or `errors` field, and a
  /// [BbxApiFormatException] when the response is neither empty nor an
  /// object.
  Future<void> uploadDocument({
    required List<int> fileBytes,
    required String fileName,
    required String idTypeCode,
    required String sourceDetail,
  }) async {
    final body = await _client.upload(
      '$endpoint/upload',
      fields: {
        'kycIDDocument': jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'createMyKYCIDDocument',
          'params': {
            'element': {'idTypeCode': idTypeCode, 'sourceDetail': sourceDetail},
          },
        }),
      },
      files: {'file': BbxApiFile(fileBytes, fileName: fileName)},
    );
    if (body == null) return;
    if (body is! Map<String, dynamic>) {
      throw const BbxApiFormatException('response is not a JSON object');
    }
    final result = body['result'];
    final errors = [
      if (body.containsKey('error')) body['error'],
      if (body.containsKey('errors')) body['errors'],
      if (result is Map<String, dynamic>) ...[
        ?result['error'],
        ?result['errors'],
      ],
    ];
    if (errors.isNotEmpty) {
      throw BbxApiRpcException.fromJson(errors.first ?? const {});
    }
  }
}
