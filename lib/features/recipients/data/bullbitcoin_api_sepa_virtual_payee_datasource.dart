import 'package:bb_mobile/features/recipients/data/models/sepa_virtual_payee_model.dart';
import 'package:dio/dio.dart';

/// The API refused a virtual payee request. Carries only the error code: the
/// JSON-RPC error object can quote account details.
class SepaVirtualPayeeApiException implements Exception {
  final String? code;

  const SepaVirtualPayeeApiException(this.code);

  @override
  String toString() => 'SepaVirtualPayeeApiException(${code ?? 'no code'})';
}

/// Kept apart from `BullbitcoinApiRecipientsGateway` so that the legacy
/// gateway does not grow. The recipients feature will be refactored later.
class BullbitcoinApiSepaVirtualPayeeDatasource {
  final Dio _http;
  static const _recipientsPath = '/ak/api-recipients';
  static const _apiVersion = '2.0.0';

  BullbitcoinApiSepaVirtualPayeeDatasource({required this._http});

  Future<SepaVirtualPayeeModel> activate(String recipientId) async {
    final resp = await _http.post(
      _recipientsPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'activateSepaVirtualPayee',
        'params': {'recipientId': recipientId},
      },
      options: Options(headers: {'x-api-version': _apiVersion}),
    );
    _throwIfRejected(resp);

    final result = resp.data['result'] as Map<String, dynamic>;
    return SepaVirtualPayeeModel.fromJson(
      result['element'] as Map<String, dynamic>,
    );
  }

  Future<({List<SepaVirtualPayeeModel> payees, int totalPayees})> list({
    required int page,
    required int pageSize,
  }) async {
    final resp = await _http.post(
      _recipientsPath,
      data: {
        'jsonrpc': '2.0',
        'id': '0',
        'method': 'listRecipientsFiat',
        'params': {
          'paginator': {'page': page, 'pageSize': pageSize},
          'filters': {
            'recipientTypeFiat': ['SEPA_EUR'],
          },
        },
      },
      options: Options(headers: {'x-api-version': _apiVersion}),
    );
    _throwIfRejected(resp);

    final result = resp.data['result'] as Map<String, dynamic>;
    final elements = result['elements'] as List<dynamic>? ?? const [];
    return (
      payees: [
        for (final element in elements)
          SepaVirtualPayeeModel.fromJson(element as Map<String, dynamic>),
      ],
      totalPayees: (result['totalElements'] as num).toInt(),
    );
  }

  void _throwIfRejected(Response<dynamic> resp) {
    if (resp.statusCode != 200) throw const SepaVirtualPayeeApiException(null);
    final error = resp.data is Map ? resp.data['error'] : null;
    if (error == null) return;
    final data = error is Map ? error['data'] : null;
    final apiError = data is Map ? data['apiError'] : null;
    final code = apiError is Map ? apiError['code'] : null;
    throw SepaVirtualPayeeApiException(code is String ? code : null);
  }
}
