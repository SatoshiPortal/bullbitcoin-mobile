import 'package:bb_mobile/core/mempool/domain/errors/mempool_server_exception.dart';
import 'package:bb_mobile/core/mempool/domain/ports/mempool_server_validator_port.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:dio/dio.dart';

class HttpMempoolServerValidator implements MempoolServerValidatorPort {
  static const _timeout = Duration(seconds: 5);

  @override
  Future<bool> validateServer({
    required String url,
    required MempoolServerNetwork network,
  }) async {
    try {
      final cleanUrl = url.replaceFirst(RegExp(r'^https?://'), '');
      final fullUrl = 'https://$cleanUrl';

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

      // verfy it's a valid number (block height should be > 0)
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
      throw MempoolServerValidationException(
        'Failed to connect to mempool server',
        e,
      );
    } catch (e) {
      log.warning('Validation failed with exception: $e');
      throw MempoolServerValidationException(
        'Unexpected error during validation',
        e,
      );
    }
  }
}
