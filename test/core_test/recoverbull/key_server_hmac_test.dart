import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recoverbull/recoverbull.dart';

/// Security audit, finding 4 — RecoverBull key-server fetch HMAC.
///
/// `KeyServer._fetchKey` must pass the server response's HMAC to
/// `EncryptionService.decrypt`; otherwise a malicious or compromised key
/// server can return a tampered ciphertext that decrypts silently.
///
/// The vector below is a real `encrypted_secret` for password 'password' and
/// salt 16×0x01 whose trailing HMAC was flipped by one byte. A client that
/// verifies the HMAC rejects it; the previously pinned client accepted it and
/// returned the forged backup key.
///
/// The pinned dependency includes the fix and this test guards the contract.
void main() {
  const tamperedEncryptedSecret =
      'KuNA/rKMJLYLQwZLk0IIS9685S8SZGE9Z+HZJSdsJ5STIKUtLEeLEeATLpgsKQ9PQh+EP9eFPQ09a0ocJss+S3ohri8IAZA24hjIVKypl6yqjJZgBq2z3L+7MqlDNrSe';

  test(
    'fetchBackupKey rejects an encrypted_secret with an invalid HMAC',
    () async {
      final keyServer = KeyServer(
        address: Uri.parse('http://keyserver.test/'),
        client: _FakeHttpClient(tamperedEncryptedSecret),
      );

      expect(
        () => keyServer.fetchBackupKey(
          backupId: List<int>.filled(32, 2),
          password: utf8.encode('password'),
          salt: List<int>.filled(16, 1),
        ),
        throwsA(isA<EncryptionException>()),
      );
    },
  );
}

/// Serves a fixed `encrypted_secret` JSON body for any POST — stands in for
/// a compromised RecoverBull key server.
class _FakeHttpClient implements HttpClient {
  _FakeHttpClient(this._encryptedSecret);

  final String _encryptedSecret;

  @override
  Future<HttpClientRequest> postUrl(Uri url) async =>
      _FakeHttpClientRequest(_encryptedSecret);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this._encryptedSecret);

  final String _encryptedSecret;
  final _FakeHttpHeaders _headers = _FakeHttpHeaders();

  @override
  HttpHeaders get headers => _headers;

  @override
  void write(Object? object) {}

  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse(
    json.encode({'encrypted_secret': _encryptedSecret}),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  ContentType? contentType;

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse(String body) : _bytes = utf8.encode(body);

  final List<int> _bytes;

  @override
  int get statusCode => 200;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value(_bytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
