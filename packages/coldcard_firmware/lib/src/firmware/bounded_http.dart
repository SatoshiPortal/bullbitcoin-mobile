import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'failures.dart';

/// Cap for metadata responses (downloads page, signatures.txt). Both are a few tens of KB in reality; anything approaching this is not what we asked for and must not be buffered before verification.
const int maxMetadataResponseBytes = 4 * 1024 * 1024;

/// Fetches [url] as text, refusing to buffer more than [maxBytes].
///
/// These endpoints serve unauthenticated data that is only trusted after PGP verification, so the fetch itself is bounded: size-capped here, and stall-protected by the receive timeout on the Dio instance.
Future<String> getBoundedText(
  Dio dio,
  String url, {
  required int maxBytes,
}) async {
  final Response<ResponseBody> response;
  try {
    response = await dio.get<ResponseBody>(
      url,
      options: Options(responseType: ResponseType.stream),
    );
  } on DioException catch (e) {
    throw FirmwareNetworkException(url, e.message ?? e.type.name);
  }

  final contentLength = int.tryParse(
    response.headers.value(Headers.contentLengthHeader) ?? '',
  );
  if (contentLength != null && contentLength > maxBytes) {
    throw ResponseTooLargeException(url, maxBytes);
  }

  final builder = BytesBuilder(copy: false);
  try {
    await for (final chunk in response.data!.stream) {
      builder.add(chunk);
      if (builder.length > maxBytes) {
        throw ResponseTooLargeException(url, maxBytes);
      }
    }
  } on DioException catch (e) {
    throw FirmwareNetworkException(url, e.message ?? e.type.name);
  }
  return utf8.decode(builder.takeBytes(), allowMalformed: true);
}
