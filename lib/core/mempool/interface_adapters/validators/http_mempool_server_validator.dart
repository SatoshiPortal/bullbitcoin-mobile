import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/mempool/domain/ports/mempool_server_validator_port.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/normalized_mempool_url.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:dio/dio.dart';

class HttpMempoolServerValidator implements MempoolServerValidatorPort {
  static const _timeout = Duration(seconds: 5);

  @override
  Future<Result<void, MempoolFailure>> validateServer({
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
        log.severe(
          message: 'Validation failed: Invalid status code ${response.statusCode}',
          error: 'status ${response.statusCode}',
          trace: StackTrace.current,
        );
        return const Err(MempoolValidationNotMempoolServerFailure());
      }

      // response will be a number
      if (response.data == null) {
        log.warning('Validation failed: Response data is null');
        return const Err(MempoolValidationInvalidResponseFailure());
      }

      // verify it's a valid number (block height should be > 0)
      final data = response.data;
      final blockHeight =
          data is int ? data : int.tryParse(data.toString());

      if (blockHeight == null || blockHeight <= 0) {
        log.warning('Validation failed: Invalid block height response');
        return const Err(MempoolValidationInvalidResponseFailure());
      }

      log.fine('Mempool server validation successful: $fullUrl');
      return const Ok(null);
    } on DioException catch (e, st) {
      log.severe(message: 'Validation failed with DioException', error: e, trace: st);
      return Err(_dioFailure(e, url));
    } catch (e, st) {
      log.severe(message: 'Validation failed with unexpected exception', error: e, trace: st);
      return Err(MempoolUnexpectedFailure(e.toString()));
    }
  }

  MempoolFailure _dioFailure(DioException e, String url) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      MempoolValidationTimeoutFailure(e.toString()),
    DioExceptionType.connectionError =>
      switch (e.message?.contains('Failed host lookup')) {
        true when url.contains('.onion') =>
          MempoolValidationTorNotRunningFailure(e.toString()),
        true => MempoolValidationHostNotFoundFailure(e.toString()),
        _ => MempoolValidationConnectionErrorFailure(e.toString()),
      },
    _ => switch (e.response?.statusCode) {
      404 => MempoolValidationNotMempoolServerFailure(e.toString()),
      500 => MempoolValidationServerErrorFailure(e.toString()),
      502 || 503 => MempoolValidationServerUnavailableFailure(e.toString()),
      final int s when s >= 400 && s < 500 =>
        MempoolValidationNotMempoolServerFailure(e.toString()),
      _ => MempoolValidationConnectionErrorFailure(e.toString()),
    },
  };
}
