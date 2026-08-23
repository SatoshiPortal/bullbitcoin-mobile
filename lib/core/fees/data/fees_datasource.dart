import 'dart:convert';

import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/fees/data/models/mempool_fees_model.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:dio/dio.dart';

class FeesDatasource {
  /// Builds the HTTP client for a resolved base URL. Injected so tests can
  /// supply a mock; defaults to a real Dio.
  final Dio Function(String baseUrl) _dioBuilder;

  FeesDatasource({Dio Function(String baseUrl)? dioBuilder})
    : _dioBuilder = dioBuilder ?? _defaultDioBuilder;

  static Dio _defaultDioBuilder(String baseUrl) => Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      followRedirects: false,
      validateStatus: (status) => status == 200,
    ),
  );

  /// Fetches precise (sub-1 sat/vByte) fee rates from the mempool API.
  ///
  /// Tries `/api/v1/fees/precise` first. If it fails for any reason — a
  /// server too old to expose it (404), a transient error, or a malformed
  /// body — falls back to the rounded `/api/v1/fees/recommended` so a
  /// custom/self-hosted mempool keeps working. Both endpoints return the
  /// same JSON shape, so the same model parses either. Throws only when
  /// neither endpoint yields a usable response.
  Future<MempoolFeesModel> fetchBitcoinNetworkFees({
    required String baseUrl,
  }) async {
    // Fees and mempool are application traffic and intentionally remain direct.
    final http = _dioBuilder(baseUrl);

    final fees =
        await _getFees(http, ApiServiceConstants.mempoolPreciseFeesPath) ??
        await _getFees(http, ApiServiceConstants.mempoolRecommendedFeesPath);
    if (fees == null) {
      throw MempoolFeesException('No mempool fee endpoint available');
    }

    return fees;
  }

  /// GETs a fee endpoint and parses it. Returns the model on a 200 with a
  /// well-formed body, or `null` on any failure — non-200, network/Dio
  /// error, non-object body, or a 200 whose body is missing or has a
  /// non-numeric fee field — so the caller can fall back to the next path.
  /// Parsing happens here (not at the call site) so a malformed-but-200
  /// precise response falls back to recommended instead of throwing.
  Future<MempoolFeesModel?> _getFees(Dio http, String path) async {
    try {
      final resp = await http.get<dynamic>(path);
      if (resp.statusCode != 200) return null;
      var data = resp.data;
      // Dio only auto-decodes when the server sends a JSON content-type. A
      // working-but-misconfigured self-hosted mempool returning the body as
      // text/plain would otherwise silently drop precise → recommended,
      // losing the sub-1 sat/vByte rates this whole path exists for. Decode
      // a string body before the Map check; a non-JSON string throws and is
      // caught below (→ fallback).
      if (data is String && data.isNotEmpty) {
        data = jsonDecode(data);
      }
      if (data is Map<String, dynamic>) {
        const feeKeys = [
          'fastestFee',
          'halfHourFee',
          'hourFee',
          'economyFee',
          'minimumFee',
        ];
        if (feeKeys.any(
          (key) => data[key] is! num || !(data[key] as num).isFinite,
        )) {
          return null;
        }
        return MempoolFeesModel.fromJson(data);
      }
      return null;
    } on DioException {
      return null;
    } on Exception {
      // A 200 with a malformed/partial body — `fromJson` throws on a missing
      // or non-numeric fee field. Fall back rather than failing the fetch.
      return null;
    }
  }
}

class MempoolFeesException extends BullException {
  MempoolFeesException(super.message);
}
