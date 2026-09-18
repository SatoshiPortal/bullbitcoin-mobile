import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/data/backup_json.dart';
import 'package:bb_mobile/features/wallet_backup/data/backup_server_protocol.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
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
    if (utf8.encode(encoded).length > limit) {
      return const Err(WalletBackupTooLargeFailure());
    }
    final cancel = CancelToken();
    final deadline = Timer(_timeout, () => cancel.cancel());
    try {
      return await _request(method, path, encoded, cancel).timeout(_timeout);
    } on TimeoutException {
      return const Err(WalletBackupNetworkFailure());
    } on DioException {
      return const Err(WalletBackupNetworkFailure());
    } on FormatException {
      return const Err(WalletBackupInvalidFailure());
    } on Exception {
      return const Err(WalletBackupNetworkFailure());
    } finally {
      deadline.cancel();
      // Dio's stream wrapper uses cancellation to close its native response,
      // including when a byte bound stops consumption before the body ends.
      cancel.cancel();
      await cancel.whenCancel;
    }
  }

  Future<Result<Map<String, dynamic>, WalletBackupFailure>> _request(
    String method,
    String path,
    String body,
    CancelToken cancel,
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
