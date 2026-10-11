import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/data/backup_json.dart';
import 'package:bb_mobile/features/wallet_backup/data/backup_server_protocol.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_diagnostics.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:dio/dio.dart';

/// One client and one Retry-After gate for every BULL operation. It never logs
/// payloads, retries requests itself, or shares interceptors with other APIs.
final class BackupServerHttpTransport {
  final Dio _dio;
  final Uri _origin;
  final DateTime Function() _now;
  final Duration _timeout;
  DateTime? _retryAt;

  BackupServerHttpTransport({
    required this._dio,
    required Uri origin,
    this._now = _utcNow,
    Duration timeout = const Duration(seconds: 30),
  }) : _origin = origin,
       _timeout = timeout {
    if (!{'https', 'http'}.contains(origin.scheme) ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment ||
        !{'', '/'}.contains(origin.path) ||
        timeout <= Duration.zero) {
      throw ArgumentError(
        'Expected a BULL server origin and a positive timeout',
      );
    }
  }

  Future<Result<Map<String, dynamic>, WalletBackupFailure>> send({
    required String method,
    required String path,
    required Map<String, Object?> body,
  }) async {
    if (_retryAt case final retryAt? when _now().isBefore(retryAt)) {
      return Err(WalletBackupRateLimitedFailure(retryAt));
    }
    final encoded = jsonEncode(body);
    final limit = method == 'PUT'
        ? BackupServerProtocol.maximumBodyBytes
        : BackupServerProtocol.smallBodyBytes;
    final size = utf8.encode(encoded).length;
    if (size > limit) {
      return const Err(WalletBackupTooLargeFailure());
    }
    final cancel = CancelToken();
    final deadline = Timer(_timeout, () => cancel.cancel());
    final elapsed = Stopwatch()..start();
    int? status;
    Result<Map<String, dynamic>, WalletBackupFailure> result;
    try {
      result = await _request(
        method,
        path,
        encoded,
        cancel,
        (value) => status = value,
      ).timeout(_timeout);
    } on TimeoutException {
      result = const Err(WalletBackupNetworkFailure());
    } on DioException {
      result = const Err(WalletBackupNetworkFailure());
    } on FormatException {
      result = const Err(WalletBackupInvalidFailure());
    } on Exception {
      result = const Err(WalletBackupNetworkFailure());
    } finally {
      deadline.cancel();
      // Dio's stream wrapper uses cancellation to close its native response,
      // including when a byte bound stops consumption before the body ends.
      cancel.cancel();
      await cancel.whenCancel;
    }
    elapsed.stop();
    final failure = switch (result) {
      Err(:final failure) => failure,
      Ok() => null,
    };
    // Neither the origin nor arbitrary path/method strings enter logs.
    final safePath =
        const {
          '/api/v1/wallet-backups',
          '/api/v1/wallet-backups/fetch',
        }.contains(path)
        ? path
        : 'unknown';
    final safeMethod = const {'POST', 'PUT', 'DELETE'}.contains(method)
        ? method
        : 'unknown';
    final retrySeconds = failure is WalletBackupRateLimitedFailure
        ? failure.retryAt.difference(_now()).inSeconds
        : null;
    final message =
        'wallet_backup http method=$safeMethod path=$safePath '
        'http_status=$status failure_class=${failure?.runtimeType ?? 'none'} '
        'elapsed_ms=${elapsed.elapsedMilliseconds} size_bucket=${walletBackupSizeBucket(size)} '
        'retry_after_seconds=$retrySeconds';
    if (failure == null) {
      log.fine(message);
    } else {
      log.warning(message);
    }
    return result;
  }

  Future<Result<Map<String, dynamic>, WalletBackupFailure>> _request(
    String method,
    String path,
    String body,
    CancelToken cancel,
    void Function(int?) receivedStatus,
  ) async {
    final response = await _dio.requestUri<ResponseBody>(
      _origin.resolve(path),
      data: body,
      cancelToken: cancel,
      options: Options(
        method: method,
        responseType: ResponseType.stream,
        contentType: Headers.jsonContentType,
        followRedirects: false,
        validateStatus: (_) => true,
        sendTimeout: _timeout,
        receiveTimeout: _timeout,
        headers: {'Accept': 'application/json', 'Cache-Control': 'no-store'},
      ),
    );
    final status = response.statusCode;
    receivedStatus(status);
    if (status == 429) {
      final now = _now();
      final values = response.headers['retry-after'] ?? const [];
      final dates = values
          .map((value) => _parseRetryAfter(value, now))
          .whereType<DateTime>()
          .toList();
      final retryAt = dates.isEmpty
          ? now.add(const Duration(minutes: 1))
          : dates.reduce((a, b) => a.isAfter(b) ? a : b);
      if (_retryAt == null || retryAt.isAfter(_retryAt!)) _retryAt = retryAt;
      return Err(WalletBackupRateLimitedFailure(_retryAt!));
    }
    if (status == 409) return const Err(WalletBackupConflictFailure());
    if (status == 401) return const Err(WalletBackupCredentialFailure());
    if (status == 413) return const Err(WalletBackupTooLargeFailure());
    if (status == null || status >= 500) {
      return const Err(WalletBackupNetworkFailure());
    }
    if (status != 200) return const Err(WalletBackupInvalidFailure());
    final stream = response.data;
    if (stream == null) return const Err(WalletBackupInvalidFailure());
    final limit = path.endsWith('/fetch')
        ? BackupServerProtocol.maximumBodyBytes
        : BackupServerProtocol.smallBodyBytes;
    final declared = int.tryParse(
      response.headers['content-length']?.firstOrNull ?? '',
    );
    if (declared != null && declared > limit) {
      return const Err(WalletBackupTooLargeFailure());
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream.stream) {
      if (bytes.length + chunk.length > limit) {
        return const Err(WalletBackupTooLargeFailure());
      }
      bytes.add(chunk);
    }
    return Ok(readBackupJson(utf8.decode(bytes.takeBytes())));
  }

  static DateTime? _parseRetryAfter(String value, DateTime now) {
    final seconds = int.tryParse(value.trim());
    if (seconds != null && seconds >= 0) {
      const maximumMillis = 8640000000000000;
      final available = (maximumMillis - now.millisecondsSinceEpoch) ~/ 1000;
      return seconds > available
          ? DateTime.fromMillisecondsSinceEpoch(maximumMillis, isUtc: true)
          : now.add(Duration(seconds: seconds));
    }
    try {
      final date = HttpDate.parse(value).toUtc();
      return date.isBefore(now) ? now : date;
    } on Exception {
      return null;
    }
  }
}

DateTime _utcNow() => DateTime.now().toUtc();
