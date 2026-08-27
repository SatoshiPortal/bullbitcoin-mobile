import 'package:bb_mobile/features/bullnym/public/bullnym_config.dart';
import 'package:dio/dio.dart';

const bullnymConnectTimeout = Duration(seconds: 10);
const bullnymReceiveTimeout = Duration(seconds: 15);

final class BullnymHttpDatasource {
  final Dio dio;

  BullnymHttpDatasource({String baseUrl = bullnymDefaultBaseUrl})
    : dio = Dio(
        BaseOptions(
          baseUrl: validateBullnymBaseUrl(baseUrl),
          connectTimeout: bullnymConnectTimeout,
          receiveTimeout: bullnymReceiveTimeout,
          validateStatus: (status) => status != null && status < 600,
        ),
      );

  BullnymHttpDatasource.withDio(this.dio);

  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      dio.get<dynamic>(path, queryParameters: query);

  Future<Response<dynamic>> post(String path, {Object? data}) =>
      dio.post<dynamic>(path, data: data);

  Future<Response<dynamic>> put(String path, {Object? data}) =>
      dio.put<dynamic>(path, data: data);

  Future<Response<dynamic>> delete(String path, {Object? data}) =>
      dio.delete<dynamic>(path, data: data);
}

String validateBullnymBaseUrl(String value) {
  final normalized = value.trim();
  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      uri.host.isEmpty ||
      (uri.scheme != 'https' && !_localHttp(uri))) {
    throw ArgumentError.value(value, 'baseUrl');
  }
  return normalized;
}

Uri validateBullnymPublicOrigin(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.host.isEmpty ||
      (uri.scheme != 'https' && !_localHttp(uri)) ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw ArgumentError.value(value, 'publicBaseUrl');
  }
  return uri;
}

bool _localHttp(Uri uri) =>
    uri.scheme == 'http' &&
    const {'localhost', '127.0.0.1', '::1'}.contains(uri.host);
