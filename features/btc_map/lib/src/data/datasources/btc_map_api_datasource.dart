import 'dart:convert';
import 'dart:isolate';

import 'package:dio/dio.dart';

import 'package:btc_map/src/data/models/merchant_model.dart';

/// BTC Map's chronological places sync (REST v4, `GET /v4/places`).
class BtcMapApiDatasource {
  static const _baseUrl = 'https://api.btcmap.org';

  final Dio _dio;

  BtcMapApiDatasource({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: _baseUrl,
              connectTimeout: const Duration(seconds: 15),
              // A cold sync is ~9 MB, uncompressed by the server.
              receiveTimeout: const Duration(seconds: 90),
              // Decoded off the UI isolate below, not by Dio on this one.
              responseType: ResponseType.plain,
            ),
          );

  Future<List<MerchantModel>> fetchPlaces({DateTime? updatedSince}) async {
    final response = await _dio.get<String>(
      '/v4/places',
      queryParameters: {
        'fields': updatedSince == null
            ? MerchantModel.apiFields
            : MerchantModel.syncFields,
        if (updatedSince != null) ...{
          'updated_since': updatedSince.toUtc().toIso8601String(),
          'include_deleted': 'true',
        },
      },
    );
    final body = response.data;
    if (body == null) throw const FormatException('Empty places response');
    return Isolate.run(() => parseMerchantModels(jsonDecode(body)));
  }
}
