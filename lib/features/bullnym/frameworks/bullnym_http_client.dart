import 'package:bb_mobile/features/bullnym/application/application_errors.dart';
import 'package:bb_mobile/features/bullnym/application/ports/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_models.dart';
import 'package:dio/dio.dart';

const bullnymBaseUrlEnvironmentKey = 'BULLNYM_BASE_URL';
const bullnymDefaultBaseUrl = String.fromEnvironment(
  bullnymBaseUrlEnvironmentKey,
  defaultValue: 'https://bullpay.ca',
);
const Duration bullnymConnectTimeout = Duration(seconds: 10);
const Duration bullnymReceiveTimeout = Duration(seconds: 15);

class BullnymHttpClient implements BullnymClientPort {
  BullnymHttpClient({Dio? dio, String baseUrl = bullnymDefaultBaseUrl})
    : _dio = dio ?? _newDio(baseUrl);

  final Dio _dio;

  String get baseUrl => _dio.options.baseUrl;

  static Dio _newDio(String baseUrl) {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: bullnymConnectTimeout,
        receiveTimeout: bullnymReceiveTimeout,
        validateStatus: (status) => status != null && status < 600,
      ),
    );
  }

  @override
  Future<BullnymRegisterResult> register(BullnymRegisterRequest request) async {
    final response = await _postMap(
      '/register',
      data: {
        'nym': request.nym,
        'ct_descriptor': request.ctDescriptor,
        'npub': request.npubHex,
        'signature': request.signatureHex,
        'timestamp': request.timestamp,
      },
    );
    return _parseRegisterResponse(response);
  }

  @override
  Future<void> deleteRegistration(
    BullnymDeleteRegistrationRequest request,
  ) async {
    await _deleteMap(
      '/register',
      data: {
        'nym': request.nym,
        'npub': request.npubHex,
        'signature': request.signatureHex,
        'timestamp': request.timestamp,
      },
    );
  }

  @override
  Future<BullnymLookupResult> lookupRegistration({
    required String npubHex,
  }) async {
    final response = await _getMap(
      '/register/lookup',
      queryParameters: {'npub': npubHex},
    );
    return _parseLookupResponse(response);
  }

  Future<Map<String, dynamic>> _getMap(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _requestMap(
      () => _dio.get<dynamic>(path, queryParameters: queryParameters),
    );
  }

  Future<Map<String, dynamic>> _postMap(String path, {Object? data}) async {
    return _requestMap(() => _dio.post<dynamic>(path, data: data));
  }

  Future<Map<String, dynamic>> _deleteMap(String path, {Object? data}) async {
    return _requestMap(() => _dio.delete<dynamic>(path, data: data));
  }

  Future<Map<String, dynamic>> _requestMap(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return _decodeMap(await request());
    } on DioException catch (e) {
      final response = e.response;
      if (response != null) return _decodeMap(response);
      throw _networkException(e);
    }
  }

  BullnymException _networkException(DioException e) {
    final isTimeout =
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout;
    return BullnymException(
      kind: isTimeout ? BullnymErrorKind.timeout : BullnymErrorKind.network,
      code: isTimeout ? 'Timeout' : 'NetworkError',
      diagnosticReason: e.message ?? 'Network request failed',
      retryable: true,
    );
  }

  Map<String, dynamic> _decodeMap(Response<dynamic> response) {
    _throwIfBullnymError(response);
    final statusCode = response.statusCode;
    if (statusCode == null || statusCode < 200 || statusCode >= 300) {
      throw _httpExceptionFromResponse(response);
    }
    final data = _requireJson(response);
    if (data is Map<String, dynamic>) return data;
    throw BullnymException.invalidServerResponse(
      diagnosticReason: 'Server returned an unexpected response shape',
      statusCode: response.statusCode,
    );
  }

  dynamic _requireJson(Response<dynamic> response) {
    final data = response.data;
    if (data == null) {
      throw BullnymException(
        kind: BullnymErrorKind.emptyResponse,
        code: 'EmptyResponse',
        diagnosticReason: 'Server returned an empty response',
        statusCode: response.statusCode,
        retryable: true,
      );
    }
    return data;
  }

  void _throwIfBullnymError(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic> && data['status'] == 'ERROR') {
      throw _serverErrorExceptionFromResponse(response);
    }
  }

  BullnymException _serverErrorExceptionFromResponse(
    Response<dynamic> response,
  ) {
    final data = response.data;
    if (data is Map<String, dynamic> && data['status'] == 'ERROR') {
      final code = data['code'];
      final reason = data['reason'];
      if (reason is! String) {
        return BullnymException.invalidServerResponse(
          diagnosticReason: 'Server error response is missing reason',
          statusCode: response.statusCode,
        );
      }
      return BullnymException(
        kind: BullnymErrorKind.serverRejectedRequest,
        code: code is String ? code : 'ServerRejectedRequest',
        diagnosticReason: reason,
        statusCode: response.statusCode,
        retryable: _isRetryableStatus(response.statusCode),
      );
    }
    return BullnymException(
      kind: BullnymErrorKind.unexpectedHttpStatus,
      code: 'HttpError',
      diagnosticReason: 'Unexpected server response',
      statusCode: response.statusCode,
      retryable: true,
    );
  }

  bool _isRetryableStatus(int? statusCode) {
    if (statusCode == null) return true;
    return statusCode == 408 || statusCode == 429 || statusCode >= 500;
  }

  BullnymException _httpExceptionFromResponse(Response<dynamic> response) {
    if (response.data is Map<String, dynamic>) {
      return _serverErrorExceptionFromResponse(response);
    }
    return BullnymException(
      kind: BullnymErrorKind.unexpectedHttpStatus,
      code: 'HttpError',
      diagnosticReason: 'Unexpected server response',
      statusCode: response.statusCode,
      retryable: true,
    );
  }

  BullnymRegisterResult _parseRegisterResponse(Map<String, dynamic> json) {
    return BullnymRegisterResult(
      nym: _requiredString(json, 'nym'),
      lightningAddress: _requiredString(json, 'lightning_address'),
    );
  }

  BullnymLookupResult _parseLookupResponse(Map<String, dynamic> json) {
    return BullnymLookupResult(
      nym: _requiredString(json, 'nym'),
      active: _requiredBool(json, 'active'),
    );
  }

  String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String) return value;
    throw BullnymException.invalidServerResponse(
      diagnosticReason: 'Server response is missing string field $key',
    );
  }

  bool _requiredBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is bool) return value;
    throw BullnymException.invalidServerResponse(
      diagnosticReason: 'Server response is missing bool field $key',
    );
  }
}
