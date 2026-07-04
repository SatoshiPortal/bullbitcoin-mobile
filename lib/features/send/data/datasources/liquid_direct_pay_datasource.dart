import 'package:bb_mobile/features/send/domain/errors/bullpay_proof_error.dart';
import 'package:bb_mobile/features/send/domain/ports/liquid_direct_pay_port.dart';
import 'package:dio/dio.dart';

/// Dio adapter for the recipient's LNURLp server. Both requests set
/// `followRedirects: false` so a malicious responder can never bounce the
/// metadata fetch or the proof-carrying callback to a foreign host (the SSRF
/// pin in the orchestrator is the primary defence; this is belt-and-braces).
class DioLiquidDirectPayDatasource implements LiquidDirectPayPort {
  final Dio _dio;

  DioLiquidDirectPayDatasource({Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));

  @override
  Future<LiquidDirectPayMetadata> fetchMetadata(Uri metadataUrl) async {
    final Map<String, dynamic> data;
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(
        metadataUrl,
        options: Options(followRedirects: false),
      );
      final body = response.data;
      if (body == null || body['tag'] != 'payRequest') {
        throw const LiquidDirectPayUnavailable();
      }
      data = body;
    } on DioException {
      throw const LiquidDirectPayUnavailable();
    }

    final paymentMethodsRaw = data['payment_methods'];
    final callbackRaw = data['callback'];
    if (paymentMethodsRaw is! List || callbackRaw is! String) {
      throw const LiquidDirectPayUnavailable();
    }

    final Uri callback;
    try {
      callback = Uri.parse(callbackRaw);
    } on FormatException {
      throw const LiquidDirectPayUnavailable();
    }

    return LiquidDirectPayMetadata(
      paymentMethods: paymentMethodsRaw.whereType<String>().toList(),
      callback: callback,
    );
  }

  @override
  Future<LiquidDirectPayCallbackResult> requestLiquidPayment(
    Uri callback, {
    required Map<String, String> query,
  }) async {
    final Map<String, dynamic> data;
    try {
      // LUD-22 callback is a GET with query params (server `Query<CallbackParams>`).
      // Merge onto any params the callback already carries so a server-supplied
      // session token survives.
      final target = callback.replace(
        queryParameters: {...callback.queryParameters, ...query},
      );
      final response = await _dio.getUri<Map<String, dynamic>>(
        target,
        options: Options(followRedirects: false),
      );
      final responseBody = response.data;
      if (responseBody == null) {
        throw const LiquidDirectPayUnavailable();
      }
      data = responseBody;
    } on DioException {
      throw const LiquidDirectPayUnavailable();
    }

    if (data['status'] == 'ERROR') {
      final details = data['details'];
      final minSat = details is Map<String, dynamic>
          ? (details['min_sat'] as num?)?.toInt()
          : null;
      return LiquidDirectPayCallbackResult(
        status: 'ERROR',
        code: data['code'] as String?,
        reason: data['reason'] as String?,
        minSat: minSat,
      );
    }

    final lbtc = data['L-BTC'];
    if (lbtc is Map<String, dynamic>) {
      return LiquidDirectPayCallbackResult(
        liquidAddress: lbtc['address'] as String?,
      );
    }

    // Soft-limit Lightning fallback: the server returned a bolt11 invoice
    // instead of an L-BTC address. Surface it so the orchestrator can decline
    // direct-pay and route the normal swap (DG-8).
    final bolt11 = data['pr'];
    if (bolt11 is String) {
      return LiquidDirectPayCallbackResult(bolt11: bolt11);
    }

    return const LiquidDirectPayCallbackResult();
  }
}
