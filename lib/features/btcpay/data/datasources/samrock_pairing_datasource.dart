import 'dart:convert';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_request.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_service_port.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

class SamRockPairingDatasource implements SamRockPairingServicePort {
  final Dio _dio;

  SamRockPairingDatasource({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              validateStatus: (status) => status != null && status < 600,
            ),
          );

  @override
  @useResult
  Future<Result<void, BtcpayFailure>> submitSetup({
    required SamRockPairingRequest request,
    required Map<String, Object?> payload,
  }) async {
    final Response<String> response;
    try {
      response = await _dio.post<String>(
        request.protocolUri.toString(),
        data: {'json': jsonEncode(payload)},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: false,
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 600,
        ),
      );
    } on Exception catch (error, trace) {
      // Once the HTTP operation starts, a transport failure cannot prove that
      // the server did not apply the submitted descriptors.
      log.warning(
        'BTCPay SamRock submission completion is uncertain',
        error: error.runtimeType,
        trace: trace,
      );
      return Err(BtcpayPairingUncertainFailure(error.runtimeType.toString()));
    }

    final body = _decodeResponse(response.data);
    final statusCode = response.statusCode ?? 0;
    final isHttpSuccess = statusCode >= 200 && statusCode < 300;
    if (!isHttpSuccess) {
      return Err(BtcpayPairingUncertainFailure('HTTP status $statusCode'));
    }

    final success = body['Success'] ?? body['success'];
    if (success == true) return const Ok(null);
    if (success == false) {
      // A successful HTTP response with an explicit false result is the only
      // outcome that proves rejection rather than transport ambiguity.
      return const Err(
        BtcpayPairingRejectedFailure('explicit server rejection'),
      );
    }
    return const Err(
      BtcpayPairingUncertainFailure('missing boolean success result'),
    );
  }

  Map<String, Object?> _decodeResponse(Object? data) {
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    if (data is String && data.trim().isNotEmpty) {
      final Object? decoded;
      try {
        decoded = jsonDecode(data);
      } on FormatException {
        return const {};
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    }
    return const {};
  }
}
