import 'package:bb_mobile/core/mempool/domain/errors/mempool_server_exception.dart';
import 'package:bb_mobile/core/mempool/domain/ports/mempool_server_validator_port.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/normalized_mempool_url.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:dio/dio.dart';

class HttpMempoolServerValidator implements MempoolServerValidatorPort {
  static const _timeout = Duration(seconds: 5);

  @override
  Future<bool> validateServer({
    required String url,
    required MempoolServerNetwork network,
    bool enableSsl = true,
  }) async {
    try {
      final normalizedUrl = NormalizedMempoolUrl(url, enableSsl: enableSsl);
      final fullUrl = normalizedUrl.fullUrl;

      final dio = Dio(
        BaseOptions(
          baseUrl: fullUrl,
          connectTimeout: _timeout,
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
        ),
      );

      // Use a simple endpoint to verify the server is a valid mempool instance.
      // This endpoint returns the current block height and works for both
      // Bitcoin and Liquid networks.
      const path = '/api/v1/blocks/tip/height';

      log.fine('Validating mempool server: $fullUrl$path');

      final response = await dio.get(path);

      if (response.statusCode != 200) {
        log.warning(
          'Validation failed: Invalid status code ${response.statusCode}',
        );
        return false;
      }

      // response will be a number
      if (response.data == null) {
        log.warning('Validation failed: Response data is null');
        return false;
      }

      // verify it's a valid number (block height should be > 0)
      final blockHeight = response.data is int
          ? response.data as int
          : int.tryParse(response.data.toString());

      if (blockHeight == null || blockHeight <= 0) {
        log.warning('Validation failed: Invalid block height response');
        return false;
      }

      log.fine('Mempool server validation successful: $fullUrl');
      return true;
    } on DioException catch (e) {
      log.warning('Validation failed with DioException: ${e.message}');
      final errorMessage = _getUserFriendlyErrorMessage(e, url);
      throw MempoolServerValidationException(errorMessage, e);
    } catch (e) {
      log.warning('Validation failed with exception: $e');
      throw MempoolServerValidationException(
        'Unexpected error during validation',
        e,
      );
    }
  }

  String _getUserFriendlyErrorMessage(DioException e, String url) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. The server may be slow or unreachable.';
    }

    if (e.type == DioExceptionType.connectionError) {
      if (e.message?.contains('Failed host lookup') ?? false) {
        if (url.contains('.onion')) {
          return 'Cannot reach .onion address. Make sure Tor/Orbot is running and try again.';
        }
        return 'Cannot find this server. Please check the URL and try again.';
      }
      return 'Unable to connect to server. Check your network connection and try again.';
    }

    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      if (statusCode == 404) {
        return 'This URL does not appear to be a mempool server. Please verify the address.';
      }
      if (statusCode == 502 || statusCode == 503) {
        return 'Server is unavailable.';
      }
      if (statusCode == 500) {
        return 'Server encountered an error.';
      }
      if (statusCode != null && statusCode >= 400 && statusCode < 500) {
        return 'Server rejected the request. Please verify the URL is correct.';
      }
    }

    return 'Failed to connect to mempool server. Please check the URL and try again.';
  }
}
