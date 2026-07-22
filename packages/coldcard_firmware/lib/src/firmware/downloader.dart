import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'failures.dart';
import 'release.dart';

/// Streams a firmware download with a size cap and progress reporting.
///
/// Returns raw bytes only. Hashing happens exactly once, in the client's verify step over its own private copy, so there is no second hash for the two to disagree about.
final class FirmwareDownloader {
  FirmwareDownloader({required this.dio, this.maxBytes = defaultMaxBytes});

  /// Real firmware is ~1-2 MB; anything near this cap is not firmware. Same sanity bound rust-coldcard uses.
  static const int defaultMaxBytes = 20 * 1024 * 1024;

  final Dio dio;
  final int maxBytes;

  /// Downloads [release] and returns its bytes.
  ///
  /// [onProgress] receives (receivedBytes, totalBytes); totalBytes is null when the server sends no content length.
  Future<Uint8List> download(
    FirmwareRelease release, {
    void Function(int received, int? total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final Response<ResponseBody> response;
    try {
      response = await dio.get<ResponseBody>(
        release.downloadUrl,
        options: Options(responseType: ResponseType.stream),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw FirmwareNetworkException(
        release.downloadUrl,
        e.message ?? e.type.name,
      );
    }

    final contentLength = int.tryParse(
      response.headers.value(Headers.contentLengthHeader) ?? '',
    );
    if (contentLength != null && contentLength > maxBytes) {
      throw FirmwareTooLargeException(maxBytes);
    }

    final bytesBuilder = BytesBuilder(copy: false);
    try {
      var received = 0;
      await for (final chunk in response.data!.stream) {
        received += chunk.length;
        if (received > maxBytes) {
          throw FirmwareTooLargeException(maxBytes);
        }
        bytesBuilder.add(chunk);
        onProgress?.call(received, contentLength);
      }
    } on DioException catch (e) {
      throw FirmwareNetworkException(
        release.downloadUrl,
        e.message ?? e.type.name,
      );
    }

    return bytesBuilder.takeBytes();
  }
}
