import 'package:bb_mobile/core/nostr/nostr_keychain_handle.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_constants.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_errors.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_models.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';
import 'package:dio/dio.dart';

const Duration bullnymConnectTimeout = Duration(seconds: 10);
const Duration bullnymReceiveTimeout = Duration(seconds: 15);

class BullnymHttpClient {
  BullnymHttpClient({Dio? dio, String baseUrl = bullnymDefaultBaseUrl})
    : _dio = dio ?? _newDio(baseUrl);

  final Dio _dio;

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

  Future<BullnymRegisterResponseDto> register({
    required NostrKeychainHandle handle,
    required String nym,
    required String ctDescriptor,
    required String verificationNpubHex,
    int? timestampSecs,
  }) async {
    final ts = timestampSecs ?? currentBullpayTimestampSecs();
    final response = await _postMap(
      '/register',
      data: {
        'nym': nym,
        'ct_descriptor': ctDescriptor,
        'verification_npub': verificationNpubHex,
        ..._signedFields(
          handle: handle,
          action: bullpayActionRegister,
          nymOrEmpty: nym,
          payloadFields: [ctDescriptor, verificationNpubHex],
          timestampSecs: ts,
        ),
      },
    );
    return BullnymRegisterResponseDto.fromJson(response);
  }

  Future<BullnymDeleteResponseDto> deleteRegistration({
    required NostrKeychainHandle handle,
    required String nym,
    int? timestampSecs,
  }) async {
    final ts = timestampSecs ?? currentBullpayTimestampSecs();
    final response = await _deleteMap(
      '/register',
      data: {
        'nym': nym,
        ..._signedFields(
          handle: handle,
          action: bullpayActionDelete,
          nymOrEmpty: nym,
          payloadFields: const [],
          timestampSecs: ts,
        ),
      },
    );
    return BullnymDeleteResponseDto.fromJson(response);
  }

  Future<BullnymLookupResponseDto> lookupRegistration({
    required String npubHex,
  }) async {
    final response = await _getMap(
      '/register/lookup',
      queryParameters: {'npub': npubHex},
    );
    return BullnymLookupResponseDto.fromJson(response);
  }

  Map<String, dynamic> _signedFields({
    required NostrKeychainHandle handle,
    required String action,
    required String nymOrEmpty,
    required List<String> payloadFields,
    required int timestampSecs,
  }) {
    return {
      'npub': handle.publicKeyHex,
      'signature': signBullpayAction(
        handle: handle,
        action: action,
        nymOrEmpty: nymOrEmpty,
        payloadFields: payloadFields,
        timestampSecs: timestampSecs,
      ),
      'timestamp': timestampSecs,
    };
  }

  Future<Map<String, dynamic>> _getMap(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _requestMap(
      () => _dio.get<dynamic>(
        path,
        queryParameters: _withoutNulls(queryParameters),
      ),
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
      throw BullnymNetworkException(_networkErrorMessage(e));
    }
  }

  String _networkErrorMessage(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout => 'Connection timed out',
      DioExceptionType.sendTimeout => 'Request timed out',
      DioExceptionType.receiveTimeout => 'Server took too long to respond',
      DioExceptionType.connectionError => 'Unable to reach Bullpay',
      _ => e.message ?? 'Network request failed',
    };
  }

  Map<String, dynamic> _decodeMap(Response<dynamic> response) {
    _throwIfBullnymError(response);
    final statusCode = response.statusCode;
    if (statusCode == null || statusCode < 200 || statusCode >= 300) {
      throw _bullnymExceptionFromResponse(response);
    }
    final data = _requireJson(response);
    if (data is Map<String, dynamic>) return data;
    throw BullnymException(
      code: 'InvalidJson',
      reason: 'Server returned an unexpected response shape',
      statusCode: response.statusCode,
    );
  }

  dynamic _requireJson(Response<dynamic> response) {
    final data = response.data;
    if (data == null) {
      throw BullnymException(
        code: 'EmptyResponse',
        reason: 'Server returned an empty response',
        statusCode: response.statusCode,
      );
    }
    return data;
  }

  void _throwIfBullnymError(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic> && data['status'] == 'ERROR') {
      throw _bullnymExceptionFromResponse(response);
    }
  }

  BullnymException _bullnymExceptionFromResponse(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic> && data['status'] == 'ERROR') {
      return BullnymException(
        code: data['code'] as String? ?? 'UnknownError',
        reason: data['reason'] as String? ?? 'Unknown server error',
        details: data['details'] as Map<String, dynamic>?,
        statusCode: response.statusCode,
      );
    }
    return BullnymException(
      code: 'HttpError',
      reason: 'Unexpected server response',
      statusCode: response.statusCode,
    );
  }

  Map<String, dynamic>? _withoutNulls(Map<String, dynamic>? source) {
    if (source == null) return null;
    return {
      for (final entry in source.entries)
        if (entry.value != null) entry.key: entry.value,
    };
  }
}
