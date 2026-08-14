import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/mempool/domain/ports/mempool_server_validator_port.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/normalized_mempool_url.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:bb_mobile/core/tor/data/datasources/tor_datasource.dart';

class HttpMempoolServerValidator implements MempoolServerValidatorPort {
  final TorDatasource? _torDatasource;

  HttpMempoolServerValidator({this._torDatasource});
  static const _timeout = Duration(seconds: 5);

  /// Genesis block hash per network — the chain's own, checksum-protected
  /// identity. Used to prove a custom server really serves the network the
  /// user picked.
  static const _knownGenesisHashes = <MempoolServerNetwork, String>{
    MempoolServerNetwork.bitcoinMainnet:
        '000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f',
    MempoolServerNetwork.bitcoinTestnet:
        '000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943',
  };

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
      if (Uri.parse(fullUrl).host.endsWith('.onion') &&
          _torDatasource != null) {
        (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient =
            _torDatasource.httpClient;
      }

      // Use a simple endpoint to verify the server is a valid mempool instance.
      // This endpoint returns the current block height and works for both
      // Bitcoin and Liquid networks.
      const path = '/api/v1/blocks/tip/height';

      log.fine('Validating mempool server');

      final response = await dio.get(path);

      final statusCode = response.statusCode;
      if (statusCode == null || statusCode < 200 || statusCode >= 300) {
        log.severe(
          message: 'Validation failed: Invalid status code $statusCode',
          error: 'status $statusCode',
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
      final blockHeight = data is int ? data : int.tryParse(data.toString());

      if (blockHeight == null || blockHeight <= 0) {
        log.warning('Validation failed: Invalid block height response');
        return const Err(MempoolValidationInvalidResponseFailure());
      }

      final genesis = await dio.get<String>('/api/block-height/0');
      final reportedGenesis = genesis.data?.trim();
      final expected = _knownGenesisHashes[network];
      if (expected != null) {
        if (reportedGenesis != expected) {
          return const Err(MempoolValidationNetworkMismatchFailure());
        }
      } else if (reportedGenesis == null ||
          _knownGenesisHashes.values.contains(reportedGenesis)) {
        // No genesis hash is pinned for this network yet (Liquid). Accepting
        // anything would let a Bitcoin server pose as a Liquid one, so at
        // minimum refuse a chain we can positively identify as a different
        // one — and refuse an unusable empty answer.
        // TODO(mempool): pin the Liquid mainnet/testnet genesis hashes.
        return const Err(MempoolValidationNetworkMismatchFailure());
      }

      log.fine('Mempool server validation successful');
      return const Ok(null);
    } on DioException catch (e, st) {
      log.severe(
        message: 'Validation failed with DioException',
        error: e,
        trace: st,
      );
      return Err(_dioFailure(e, url));
    } catch (e, st) {
      log.severe(
        message: 'Validation failed with unexpected exception',
        error: e,
        trace: st,
      );
      return const Err(
        MempoolUnexpectedFailure('Unexpected validation failure'),
      );
    }
  }

  MempoolFailure _dioFailure(DioException e, String url) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => MempoolValidationTimeoutFailure(
      'Validation timed out',
    ),
    DioExceptionType.connectionError => switch (e.message?.contains(
      'Failed host lookup',
    )) {
      true when url.contains('.onion') => MempoolValidationTorNotRunningFailure(
        'Tor is not running',
      ),
      true => const MempoolValidationHostNotFoundFailure(),
      _ => const MempoolValidationConnectionErrorFailure(),
    },
    _ => switch (e.response?.statusCode) {
      404 => const MempoolValidationNotMempoolServerFailure(),
      500 => const MempoolValidationServerErrorFailure(),
      502 || 503 => const MempoolValidationServerUnavailableFailure(),
      final int s when s >= 400 && s < 500 =>
        const MempoolValidationNotMempoolServerFailure(),
      _ => const MempoolValidationConnectionErrorFailure(),
    },
  };
}
