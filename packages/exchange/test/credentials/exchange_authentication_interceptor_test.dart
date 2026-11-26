import 'package:exchange/setup.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:bbx_api/bbx_api.dart'
    show
        Bbx,
        BbxCredentialUnavailableFailure,
        BbxFailure,
        BbxMissingCredentialFailure;
import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart'
    show Headers, HttpClientAdapter, RequestOptions, ResponseBody;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

/// Records the key of each request and answers a valid JSON-RPC result.
class _Adapter implements HttpClientAdapter {
  final keys = <Object?>[];
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    keys.add(options.headers['X-API-Key']);
    paths.add(options.path);
    return ResponseBody.fromString(
      jsonEncode({
        'jsonrpc': '2.0',
        'result': {'success': true},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String _record(String key, {bool active = true}) =>
    jsonEncode({'key': key, 'isActive': active});

/// The app's credential read as the package's own failure family, as the
/// composition root wires it.
Future<Result<String?, BbxFailure>> _credential(
  ExchangeCredentials repository, {
  required bool isTestnet,
}) async => switch (await repository.readActiveApiKey(isTestnet: isTestnet)) {
  Ok(:final value) => Ok<String?, BbxFailure>(value),
  Err() => const Err<String?, BbxFailure>(BbxCredentialUnavailableFailure()),
};

Bbx _client(
  HttpClientAdapter adapter,
  ExchangeCredentials repository, {
  required bool isTestnet,
}) => bbxForTesting(
  endpoint: 'https://example.invalid',
  adapter: adapter,
  readActiveApiKey: () => _credential(repository, isTestnet: isTestnet),
);

/// Consents through the real transport, failing the test on any failure.
Future<bool> _consent(Bbx api) async =>
    switch (await api.users.registerResponsibilityConsent()) {
      Ok(:final value) => value,
      Err(:final failure) => fail('unexpected failure: $failure'),
    };

void main() {
  test('rereads rotation, environment and logout on every request', () async {
    final storage = FakeSecureStoragePlatform().install();
    final repository = ExchangeCredentials.open(
      Secrets(scratchDirectory: () async => '/tmp').exchangeKeychain,
    );
    final adapter = _Adapter();
    final mainnet = _client(adapter, repository, isTestnet: false);
    final testnet = _client(adapter, repository, isTestnet: true);
    storage.entries['exchange_api_key'] = _record('main');
    storage.entries['exchange_api_key_testnet'] = _record('test');
    expect(await _consent(mainnet), isTrue);
    expect(await _consent(testnet), isTrue);
    storage.entries['exchange_api_key'] = _record('rotated');
    expect(await _consent(mainnet), isTrue);
    storage.entries.remove('exchange_api_key');
    expect(
      await mainnet.users.registerResponsibilityConsent(),
      isA<Err>().having(
        (r) => r.failure,
        'signed out',
        isA<BbxMissingCredentialFailure>(),
      ),
    );
    expect(adapter.keys, ['main', 'test', 'rotated']);
    expect(adapter.paths, everyElement('/ak/api-users'));
  });

  test(
    'inactive, corrupt and inaccessible credentials never reach the adapter',
    () async {
      final storage = FakeSecureStoragePlatform().install();
      final repository = ExchangeCredentials.open(
        Secrets(scratchDirectory: () async => '/tmp').exchangeKeychain,
      );
      final adapter = _Adapter();
      final api = _client(adapter, repository, isTestnet: true);
      storage.entries['exchange_api_key_testnet'] = _record(
        'inactive',
        active: false,
      );
      expect(
        await api.users.registerResponsibilityConsent(),
        isA<Err>().having(
          (r) => r.failure,
          'inactive',
          isA<BbxMissingCredentialFailure>(),
        ),
      );
      storage.entries['exchange_api_key_testnet'] =
          '{"key":"SYNTHETIC-PRIVATE", broken';
      expect(
        await api.users.registerResponsibilityConsent(),
        isA<Err>()
            .having(
              (r) => r.failure,
              'invalid',
              isA<BbxCredentialUnavailableFailure>(),
            )
            .having(
              (r) => '${r.failure} ${r.failure.logMessage}',
              'sanitized',
              isNot(contains('SYNTHETIC-PRIVATE')),
            ),
      );
      storage.scripted.add(Exception('SYNTHETIC-PRIVATE'));
      expect(
        await api.users.registerResponsibilityConsent(),
        isA<Err>().having(
          (r) => r.failure,
          'unavailable',
          isA<BbxCredentialUnavailableFailure>(),
        ),
      );
      expect(adapter.keys, isEmpty);
    },
  );

  test(
    'an Error from the credential read propagates and sends nothing',
    () async {
      final adapter = _Adapter();
      final api = bbxForTesting(
        endpoint: 'https://example.invalid',
        adapter: adapter,
        readActiveApiKey: () async => throw StateError('programmer bug'),
      );
      await expectLater(
        api.users.registerResponsibilityConsent(),
        throwsA(isA<StateError>()),
      );
      expect(adapter.keys, isEmpty);
    },
  );

  test('typed absence and read failure are separate outcomes', () async {
    final storage = FakeSecureStoragePlatform().install();
    final repository = ExchangeCredentials.open(
      Secrets(scratchDirectory: () async => '/tmp').exchangeKeychain,
    );
    final adapter = _Adapter();
    final api = _client(adapter, repository, isTestnet: true);
    expect(
      await api.users.registerResponsibilityConsent(),
      isA<Err>()
          .having(
            (r) => r.failure,
            'absence',
            isA<BbxMissingCredentialFailure>(),
          )
          .having(
            (r) => r.failure,
            'not a read failure',
            isNot(isA<BbxCredentialUnavailableFailure>()),
          ),
    );
    storage.scripted.add(Exception());
    expect(
      await api.users.registerResponsibilityConsent(),
      isA<Err>()
          .having(
            (r) => r.failure,
            'read failure',
            isA<BbxCredentialUnavailableFailure>(),
          )
          .having(
            (r) => r.failure,
            'not an absence',
            isNot(isA<BbxMissingCredentialFailure>()),
          ),
    );
    expect(adapter.keys, isEmpty);
  });
}
