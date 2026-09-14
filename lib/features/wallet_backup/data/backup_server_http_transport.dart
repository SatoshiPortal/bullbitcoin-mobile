import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_server_config.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:dio/dio.dart';

const walletBackupConnectTimeout = Duration(seconds: 10);
const walletBackupReceiveTimeout = Duration(seconds: 15);

/// Decides what a server error envelope means for one protocol.
typedef BackupServerFailureDecoder =
    WalletBackupFailure Function(
      int? status,
      Headers headers,
      Map<String, Object?> json,
    );

/// One HTTP conversation with the backup server.
///
/// The two protocols the server speaks share an origin, timeouts, redirect
/// policy and error envelope, and differ only in their routes, bodies and error
/// codes — so each repository brings its own decoder and keeps its own rate
/// limit gate, the server counting them in separate buckets.
final class BackupServerHttpTransport {
  final Dio _dio;
  final WalletBackupOriginProvider _origin;
  final DateTime Function() _now;
  DateTime? _notBefore;

  BackupServerHttpTransport(this._dio, this._origin, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  factory BackupServerHttpTransport.defaults({
    WalletBackupOriginProvider origin = defaultWalletBackupOrigin,
  }) => BackupServerHttpTransport(
    Dio(
      BaseOptions(
        connectTimeout: walletBackupConnectTimeout,
        receiveTimeout: walletBackupReceiveTimeout,
      ),
    ),
    origin,
  );

  Future<Result<Map<String, Object?>, WalletBackupFailure>> request({
    required String method,
    required String path,
    required Map<String, Object?> body,
    required BackupServerFailureDecoder decodeServerFailure,
  }) async {
    final notBefore = _notBefore;
    if (notBefore != null) {
      final remaining = notBefore.difference(_now().toUtc());
      if (!remaining.isNegative && remaining != Duration.zero) {
        return Err(WalletBackupRateLimitedFailure(remaining));
      }
    }
    final Uri origin;
    try {
      origin = await _origin();
    } on Exception {
      return const Err(WalletBackupInvalidServerOriginFailure());
    }
    try {
      final response = await _dio.requestUri<Object?>(
        origin.resolve(path),
        data: body,
        options: Options(
          method: method,
          followRedirects: false,
          responseType: ResponseType.json,
          validateStatus: (status) => status != null && status < 600,
        ),
      );
      return _handleResponse(response, decodeServerFailure);
    } on DioException catch (error, trace) {
      if (error.response case final response?) {
        return _handleResponse(response, decodeServerFailure);
      }
      log.warning(
        'Wallet backup network request failed',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(WalletBackupRemoteUnavailableFailure());
    } on Exception catch (error, trace) {
      log.warning(
        'Wallet backup request failed unexpectedly',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(WalletBackupUnexpectedFailure());
    }
  }

  /// Closes the local gate for as long as the server asked, then reports the
  /// refusal. A missing or negative delay is not a rate limit this client can
  /// honour, so it is treated as an answer it cannot authenticate.
  WalletBackupFailure rateLimited(Headers headers) {
    final seconds = int.tryParse(headers.value('retry-after') ?? '');
    if (seconds == null || seconds < 0) {
      return const WalletBackupInvalidRemoteFailure();
    }
    final retryAfter = Duration(seconds: seconds);
    _notBefore = _now().toUtc().add(retryAfter);
    return WalletBackupRateLimitedFailure(retryAfter);
  }

  Result<Map<String, Object?>, WalletBackupFailure> _handleResponse(
    Response<Object?> response,
    BackupServerFailureDecoder decodeServerFailure,
  ) {
    final json = backupServerObject(response.data);
    if (json == null) return const Err(WalletBackupInvalidRemoteFailure());
    if (json['status'] == 'ERROR') {
      if (!backupServerHasOnly(json, const {'status', 'code', 'reason'}) ||
          json['code'] is! String ||
          json['reason'] is! String) {
        return const Err(WalletBackupInvalidRemoteFailure());
      }
      return Err(
        decodeServerFailure(response.statusCode, response.headers, json),
      );
    }
    final status = response.statusCode;
    return status != null && status >= 200 && status < 300
        ? Ok(json)
        : const Err(WalletBackupInvalidRemoteFailure());
  }
}

Map<String, Object?>? backupServerObject(Object? value) {
  if (value is! Map) return null;
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) return null;
    result[entry.key as String] = entry.value;
  }
  return result;
}

bool backupServerHasOnly(Map<String, Object?> json, Set<String> allowed) =>
    json.keys.every(allowed.contains);
