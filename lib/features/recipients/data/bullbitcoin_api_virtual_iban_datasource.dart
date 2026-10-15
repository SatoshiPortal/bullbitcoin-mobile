import 'package:bb_mobile/features/recipients/data/models/virtual_iban_model.dart';
import 'package:dio/dio.dart';

/// The API refused a virtual IBAN request. Carries only the error code: the
/// JSON-RPC error object can quote account details.
class VirtualIbanApiException implements Exception {
  final String? code;

  const VirtualIbanApiException(this.code);

  @override
  String toString() => 'VirtualIbanApiException(${code ?? 'no code'})';
}

/// Kept apart from `BullbitcoinApiRecipientsGateway` so that the legacy
/// gateway does not grow. The recipients feature will be refactored later.
class BullbitcoinApiVirtualIbanDatasource {
  final Dio _http;
  static const _recipientsPath = '/ak/api-recipients';
  static const _apiVersion = '2.0.0';

  BullbitcoinApiVirtualIbanDatasource({required this._http});

  Future<VirtualIbanModel?> find() async {
    final resp = await _http.post(
      _recipientsPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'listRecipientsFiat',
        'params': {
          'paginator': {'page': 1, 'pageSize': 1},
          'filters': {
            'recipientTypeFiat': ['SEPA_EUR_VIRTUAL_ACCOUNT'],
            'isOwner': true,
          },
        },
      },
      options: Options(headers: {'x-api-version': _apiVersion}),
    );
    _throwIfRejected(resp);

    final result = resp.data['result'] as Map<String, dynamic>?;
    final elements = result?['elements'] as List<dynamic>? ?? const [];
    if (elements.isEmpty) return null;
    return VirtualIbanModel.fromJson(elements.first as Map<String, dynamic>);
  }

  Future<VirtualIbanModel> create() async {
    final resp = await _http.post(
      _recipientsPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'createMyRecipient',
        'params': {
          'element': {'recipientType': 'FR_VIRTUAL_ACCOUNT', 'isOwner': true},
        },
      },
    );
    _throwIfRejected(resp);

    final result = resp.data['result'] as Map<String, dynamic>;
    return VirtualIbanModel.fromJson(result['element'] as Map<String, dynamic>);
  }

  void _throwIfRejected(Response<dynamic> resp) {
    if (resp.statusCode != 200) throw const VirtualIbanApiException(null);
    final error = resp.data is Map ? resp.data['error'] : null;
    if (error == null) return;
    final data = error is Map ? error['data'] : null;
    final apiError = data is Map ? data['apiError'] : null;
    final code = apiError is Map ? apiError['code'] : null;
    throw VirtualIbanApiException(code is String ? code : null);
  }
}
