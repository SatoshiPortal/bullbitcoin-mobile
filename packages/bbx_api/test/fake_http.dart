import 'dart:convert';
import 'dart:typed_data';

import 'package:bbx_api/bbx_api.dart';
import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:primitives/primitives.dart';

/// Answers every request with [status] and [body], recording the requests.
class FakeHttp implements HttpClientAdapter {
  final int status;
  final Object? body;
  final List<RequestOptions> requests = [];

  /// The encoded body of each request that had one.
  final List<List<int>> bodies = [];

  FakeHttp({this.status = 200, this.body});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      bodies.add([for (final chunk in await requestStream.toList()) ...chunk]);
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A credential read that finds [key], or no key when it is null.
Future<Result<String?, BbxFailure>> okApiKey([
  String? key = 'test-key',
]) async => Ok<String?, BbxFailure>(key);

/// A credential read that fails: the stored credential is unreadable.
Future<Result<String?, BbxFailure>> failedApiKey() async =>
    const Err(BbxCredentialUnavailableFailure());

/// A [Bbx] over [http], presenting the key [readActiveApiKey] returns.
Bbx bbx(
  HttpClientAdapter http, {
  Future<Result<String?, BbxFailure>> Function()? readActiveApiKey,
  BbxTimeouts timeouts = const BbxTimeouts(),
}) => bbxForTesting(
  endpoint: 'https://api.test',
  adapter: http,
  readActiveApiKey: readActiveApiKey ?? okApiKey,
  timeouts: timeouts,
);
