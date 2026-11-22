import 'dart:convert';

import 'package:bbx_api/src/bbx_failure.dart';
import 'package:bbx_api/src/bbx_transport.dart';
import 'package:bbx_api/src/rpc_error.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The `api-kyc` endpoint.
final class KycApi {
  static const endpoint = '/ak/api-kyc';

  final BbxTransport _transport;

  @internal
  KycApi(this._transport);

  /// Uploads an identity document file as the `file` form field, with a
  /// `createMyKYCIDDocument` request for [idTypeCode] and [sourceDetail] in
  /// the `kycIDDocument` field.
  ///
  /// Fails with a [BbxRpcFailure] when the response object, or its `result`
  /// object, carries an `error` or `errors` field, and a
  /// [BbxResponseFormatFailure] when the response is neither empty nor an
  /// object.
  Future<Result<void, BbxFailure>> uploadDocument({
    required List<int> fileBytes,
    required String fileName,
    required String idTypeCode,
    required String sourceDetail,
  }) => _transport.upload(
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
    files: {'file': BbxFile(fileBytes, fileName: fileName)},
    read: (body) {
      if (body == null) return const Ok<void, BbxFailure>(null);
      if (body is! Map<String, dynamic>) {
        return const Err(
          BbxResponseFormatFailure('response is not a JSON object'),
        );
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
        return Err(bbxRpcFailure(errors.first ?? const {}));
      }
      return const Ok<void, BbxFailure>(null);
    },
  );
}
