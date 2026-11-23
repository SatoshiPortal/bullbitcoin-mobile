import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bbx_api/bbx_api.dart';
import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:primitives/primitives.dart';

/// The endpoint a test client posts to. Its adapter answers the request, so
/// the host is never resolved.
const testBbxEndpoint = 'https://example.invalid';

/// The credential of a client built without a [ReadExchangeApiKey].
///
/// The old client attached no authentication, so its requests still left the
/// app; returning a key here keeps those requests observable instead of
/// turning them into a missing-credential failure.
const anonymousTestApiKey = 'synthetic-anonymous-key';

/// The credential the package reads before each request, from the app's
/// [readApiKey].
///
/// A key stays a key and an unreadable credential becomes
/// [BbxCredentialUnavailableFailure]. Without [readApiKey], the read returns
/// [anonymousTestApiKey].
Future<Result<String?, BbxFailure>> Function() bbxCredentialRead(
  ReadExchangeApiKey? readApiKey,
) => readApiKey == null
    ? () async => const Ok<String?, BbxFailure>(anonymousTestApiKey)
    : () async => switch (await readApiKey()) {
        Ok(:final value) => Ok<String?, BbxFailure>(value),
        Err() => const Err<String?, BbxFailure>(
          BbxCredentialUnavailableFailure(),
        ),
      };

/// Answers each request with [status] and [body], or throws [error].
class FakeBbxHttp implements HttpClientAdapter {
  final int status;
  final Object? body;
  final DioExceptionType? error;
  final List<RequestOptions> requests = [];

  FakeBbxHttp({this.status = 200, this.body, this.error});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (error case final type?) {
      throw DioException(requestOptions: options, type: type);
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

  /// A client on this adapter; with [readApiKey], the app's credential read
  /// runs before every request.
  Bbx client({ReadExchangeApiKey? readApiKey}) => bbxForTesting(
    endpoint: testBbxEndpoint,
    adapter: this,
    readActiveApiKey: bbxCredentialRead(readApiKey),
  );
}
