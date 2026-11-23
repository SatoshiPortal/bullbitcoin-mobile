import 'package:bbx_api/src/bbx_failure.dart';
import 'package:bbx_api/src/bbx_format_exception.dart';
import 'package:bbx_api/src/bbx_timeouts.dart';
import 'package:bbx_api/src/rpc_error.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The authenticated JSON-RPC transport behind `Bbx`.
///
/// Internal: callers build a `Bbx` and use its operations. Every request reads
/// the credential first, so a signed-out user or an unreadable credential
/// never reaches the network, and each request carries the key read for it.
@internal
final class BbxTransport {
  final Dio http;
  final Future<Result<String?, BbxFailure>> Function() readActiveApiKey;

  BbxTransport({required this.http, required this.readActiveApiKey});

  bool _sessionRejected = false;

  /// Whether the server answered HTTP 401 to a request this transport sent:
  /// every request carries the key read for it, so the key is no longer
  /// valid. Never set by a request that was not sent.
  bool get sessionRejected => _sessionRejected;

  /// A transport for the API at [endpoint], with [timeouts] on each phase.
  factory BbxTransport.open({
    required String endpoint,
    required Future<Result<String?, BbxFailure>> Function() readActiveApiKey,
    BbxTimeouts timeouts = const BbxTimeouts(),
  }) => BbxTransport(
    http: dio(endpoint: endpoint, timeouts: timeouts),
    readActiveApiKey: readActiveApiKey,
  );

  /// A transport for the API at [endpoint] over [adapter]. Test seam.
  factory BbxTransport.testing({
    required String endpoint,
    required HttpClientAdapter adapter,
    required Future<Result<String?, BbxFailure>> Function() readActiveApiKey,
    BbxTimeouts timeouts = const BbxTimeouts(),
  }) => BbxTransport(
    http: dio(endpoint: endpoint, timeouts: timeouts)
      ..httpClientAdapter = adapter,
    readActiveApiKey: readActiveApiKey,
  );

  /// The HTTP client for [endpoint]: the caller's timeouts and nothing else.
  static Dio dio({required String endpoint, required BbxTimeouts timeouts}) =>
      Dio(
        BaseOptions(
          baseUrl: endpoint,
          connectTimeout: timeouts.connect,
          sendTimeout: timeouts.send,
          receiveTimeout: timeouts.receive,
        ),
      );

  /// Sends a JSON-RPC request for [method] to [endpoint] and reads its
  /// `result` with [read].
  ///
  /// [id] is the JSON-RPC request id and [headers] are added to the request's
  /// headers. [rejection] reads a JSON-RPC error object into the failure to
  /// return.
  Future<Result<T, BbxFailure>> request<T>(
    String endpoint,
    String method, {
    Map<String, Object?> params = const {},
    String id = '0',
    Map<String, Object?>? headers,
    BbxFailure Function(Object error) rejection = bbxRpcFailure,
    required T Function(Object? result) read,
  }) async {
    final credential = await _credential();
    return switch (credential) {
      Err(:final failure) => Err<T, BbxFailure>(failure),
      Ok(:final value) => await _post(
        endpoint,
        {'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params},
        headers: {'X-API-Key': value, ...?headers},
        read: (body) => Ok(read(_resultOf(body, rejection))),
      ),
    };
  }

  /// Sends the write [method] like [request], reading its `result` with
  /// [read] inside the same classification.
  ///
  /// A failure after the request may have reached the server is a
  /// [BbxOutcomeUnknownFailure] (see [writeFailure]): the write may have
  /// happened. A JSON-RPC refusal and a failure before sending are returned
  /// unchanged.
  Future<Result<T, BbxFailure>> write<T>(
    String endpoint,
    String method, {
    Map<String, Object?> params = const {},
    String id = '0',
    Map<String, Object?>? headers,
    BbxFailure Function(Object error) rejection = bbxRpcFailure,
    required T Function(Object? result) read,
  }) async {
    final result = await request(
      endpoint,
      method,
      params: params,
      id: id,
      headers: headers,
      rejection: rejection,
      read: read,
    );
    return switch (result) {
      Ok() => result,
      Err(:final failure) => Err(writeFailure(failure)),
    };
  }

  /// Posts a `multipart/form-data` request to [path] with [fields] and
  /// [files], keyed by form field name, and reads the response body with
  /// [read].
  Future<Result<T, BbxFailure>> upload<T>(
    String path, {
    Map<String, String> fields = const {},
    Map<String, BbxFile> files = const {},
    required Result<T, BbxFailure> Function(Object? body) read,
  }) async {
    final credential = await _credential();
    return switch (credential) {
      Err(:final failure) => Err<T, BbxFailure>(failure),
      Ok(:final value) => await _post(
        path,
        FormData()
          ..fields.addAll(fields.entries)
          ..files.addAll([
            for (final MapEntry(:key, :value) in files.entries)
              MapEntry(
                key,
                MultipartFile.fromBytes(value.bytes, filename: value.fileName),
              ),
          ]),
        headers: {'X-API-Key': value},
        contentType: 'multipart/form-data',
        read: read,
      ),
    };
  }

  /// The `result` of the JSON-RPC [body], or the failure [rejection] reads
  /// from its error object.
  Object? _resultOf(Object? body, BbxFailure Function(Object error) rejection) {
    if (body is! Map<String, dynamic>) {
      throw const BbxFormatException('response is not a JSON object');
    }
    if (body['error'] case final Object error) {
      throw _Rejection(rejection(error));
    }
    return body['result'];
  }

  Future<Result<T, BbxFailure>> _post<T>(
    String path,
    Object? data, {
    required Map<String, Object?> headers,
    required Result<T, BbxFailure> Function(Object? body) read,
    String? contentType,
  }) async {
    final Response<Object?> response;
    try {
      response = await http.post<Object?>(
        path,
        data: data,
        options: Options(headers: headers, contentType: contentType),
      );
    } on DioException catch (e) {
      if (e.error case final Error bug) {
        Error.throwWithStackTrace(bug, e.stackTrace);
      }
      if (e.response?.statusCode == 401) _sessionRejected = true;
      return Err(transportFailure(e));
    }
    if (response.statusCode == 401) _sessionRejected = true;
    if (response.statusCode != 200) {
      return Err(
        BbxHttpFailure(response.statusCode, origin: StackTrace.current),
      );
    }
    try {
      return read(response.data);
    } on _Rejection catch (rejection, st) {
      return Err(_withOrigin(rejection.failure, st));
    } on BbxFormatException catch (e, st) {
      return Err(BbxResponseFormatFailure(e.reason, origin: st));
    }
  }

  /// The API key of this request, or the failure that stops it before the
  /// network. An [Error] from the credential read propagates unchanged.
  Future<Result<String, BbxFailure>> _credential() async {
    final Result<String?, BbxFailure> stored;
    try {
      stored = await readActiveApiKey();
    } on Error {
      rethrow;
    } on Exception {
      return const Err(BbxCredentialUnavailableFailure());
    }
    return switch (stored) {
      Ok(value: final String key) => Ok(key),
      Ok() => const Err(BbxMissingCredentialFailure()),
      Err() => const Err(BbxCredentialUnavailableFailure()),
    };
  }
}

/// A file sent in a multipart upload.
@internal
final class BbxFile {
  final List<int> bytes;
  final String fileName;

  const BbxFile(this.bytes, {required this.fileName});
}

/// A JSON-RPC error raised while reading a body, so that [_post] can report it
/// as the failure its reader built.
final class _Rejection implements Exception {
  final BbxFailure failure;

  const _Rejection(this.failure);
}

BbxFailure _withOrigin(
  BbxFailure failure,
  StackTrace origin,
) => switch (failure) {
  BbxMissingCredentialFailure() => const BbxMissingCredentialFailure(),
  BbxCredentialUnavailableFailure() => const BbxCredentialUnavailableFailure(),
  BbxHttpFailure(:final status) => BbxHttpFailure(status, origin: origin),
  BbxRpcFailure(
    :final code,
    :final message,
    :final apiCode,
    :final requestId,
  ) =>
    BbxRpcFailure(
      code: code,
      message: message,
      apiCode: apiCode,
      requestId: requestId,
      origin: origin,
    ),
  BbxOrderLimitFailure(
    :final bound,
    :final amount,
    :final currency,
    :final code,
    :final apiCode,
    :final requestId,
  ) =>
    BbxOrderLimitFailure(
      bound: bound,
      amount: amount,
      currency: currency,
      code: code,
      apiCode: apiCode,
      requestId: requestId,
      origin: origin,
    ),
  BbxConfidentialSepaInactiveFailure(
    :final code,
    :final apiCode,
    :final requestId,
  ) =>
    BbxConfidentialSepaInactiveFailure(
      code: code,
      apiCode: apiCode,
      requestId: requestId,
      origin: origin,
    ),
  BbxTimeoutFailure(:final kind) => BbxTimeoutFailure(kind, origin: origin),
  BbxConnectionFailure() => BbxConnectionFailure(origin: origin),
  BbxBadCertificateFailure() => BbxBadCertificateFailure(origin: origin),
  BbxRequestCancelledFailure() => BbxRequestCancelledFailure(origin: origin),
  BbxTransformTimeoutFailure() => BbxTransformTimeoutFailure(origin: origin),
  BbxTransportFailure() => BbxTransportFailure(origin: origin),
  BbxOutcomeUnknownFailure(:final reason) => BbxOutcomeUnknownFailure(
    reason,
    origin: origin,
  ),
  BbxResponseFormatFailure(:final reason) => BbxResponseFormatFailure(
    reason,
    origin: origin,
  ),
};

/// The failure of a write that failed with [failure].
///
/// A failure after the request may have reached the server becomes a
/// [BbxOutcomeUnknownFailure]: a send or receive timeout, a dropped
/// connection, an unknown transport failure, a gateway error (502, 504), a
/// status below 400 other than 200, a bad response without a status, or a
/// reply that could not be read. A missing or unreadable credential, a
/// connect timeout, a rejected certificate and a cancel happen before
/// sending; a JSON-RPC refusal and any other HTTP status are the server's
/// answer. Those are returned unchanged.
BbxFailure writeFailure(BbxFailure failure) => switch (failure) {
  BbxTimeoutFailure(:final kind, :final origin) => switch (kind) {
    BbxTimeoutKind.connect => failure,
    BbxTimeoutKind.send || BbxTimeoutKind.receive => BbxOutcomeUnknownFailure(
      '${kind.name} timeout',
      origin: origin,
    ),
  },
  BbxConnectionFailure(:final origin) => BbxOutcomeUnknownFailure(
    'connection lost',
    origin: origin,
  ),
  BbxTransformTimeoutFailure(:final origin) => BbxOutcomeUnknownFailure(
    'transform timeout',
    origin: origin,
  ),
  BbxTransportFailure(:final origin) => BbxOutcomeUnknownFailure(
    'transport failure',
    origin: origin,
  ),
  BbxHttpFailure(:final status, :final origin)
      when status == null || status < 400 || status == 502 || status == 504 =>
    BbxOutcomeUnknownFailure('status $status', origin: origin),
  BbxResponseFormatFailure(:final reason, :final origin) =>
    BbxOutcomeUnknownFailure(reason, origin: origin),
  BbxHttpFailure() ||
  BbxMissingCredentialFailure() ||
  BbxCredentialUnavailableFailure() ||
  BbxRpcFailure() ||
  BbxOrderLimitFailure() ||
  BbxConfidentialSepaInactiveFailure() ||
  BbxBadCertificateFailure() ||
  BbxRequestCancelledFailure() ||
  BbxOutcomeUnknownFailure() => failure,
};

/// The failure of a failed request.
///
/// A refused status is an HTTP failure even when the option only saw the
/// exception. An [Error] never reaches here.
BbxFailure transportFailure(DioException error) {
  final origin = error.stackTrace;
  if (error.response?.statusCode case final int status) {
    return BbxHttpFailure(status, origin: origin);
  }
  return switch (error.type) {
    DioExceptionType.connectionTimeout => BbxTimeoutFailure(
      BbxTimeoutKind.connect,
      origin: origin,
    ),
    DioExceptionType.sendTimeout => BbxTimeoutFailure(
      BbxTimeoutKind.send,
      origin: origin,
    ),
    DioExceptionType.receiveTimeout => BbxTimeoutFailure(
      BbxTimeoutKind.receive,
      origin: origin,
    ),
    DioExceptionType.connectionError => BbxConnectionFailure(origin: origin),
    DioExceptionType.badCertificate => BbxBadCertificateFailure(origin: origin),
    DioExceptionType.cancel => BbxRequestCancelledFailure(origin: origin),
    DioExceptionType.badResponse => BbxHttpFailure(null, origin: origin),
    // This is not a receive timeout for callers: the response had arrived,
    // but its transformation did not finish.
    DioExceptionType.transformTimeout => BbxTransformTimeoutFailure(
      origin: origin,
    ),
    DioExceptionType.unknown => BbxTransportFailure(origin: origin),
  };
}
