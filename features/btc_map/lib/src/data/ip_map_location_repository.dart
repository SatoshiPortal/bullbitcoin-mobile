import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/bull_map_failure.dart';
import '../domain/entities/geo_point.dart';
import '../domain/repositories/map_location_repository.dart';
import 'models/ip_location_model.dart';

/// Best-effort centering from the connection's public IP, without GPS access.
/// The provider sees the connection IP and generic HTTP metadata; no Bull,
/// wallet or user identifiers are added, and neither the IP nor result is logged.
final class IpMapLocationRepository implements MapLocationRepository {
  static const _timeout = Duration(seconds: 3);

  final Dio Function() _createClient;

  IpMapLocationRepository({Dio Function()? createClient})
    : _createClient = createClient ?? _newClient;

  @override
  @useResult
  Future<Result<GeoPoint, BullMapFailure>> locate() async {
    final client = _createClient()
      ..httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () => HttpClient()..userAgent = null,
      );
    try {
      final response = await client
          .get<Object?>(
            'https://ipwho.is/',
            queryParameters: {'fields': 'success,latitude,longitude'},
          )
          .timeout(_timeout);
      final point = IpLocationModel.fromJson(response.data).toDomain();
      return point == null ? const Err(BullMapUnexpectedFailure()) : Ok(point);
    } on DioException {
      return const Err(BullMapNetworkFailure());
    } on TimeoutException {
      return const Err(BullMapNetworkFailure());
    } on Exception {
      return const Err(BullMapUnexpectedFailure());
    } finally {
      client.close(force: true);
    }
  }

  static Dio _newClient() => Dio(
    BaseOptions(
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
      followRedirects: false,
    ),
  );
}
