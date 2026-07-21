import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/data/bullnym_http_client.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_config.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockHttpAdapter extends Mock implements HttpClientAdapter {}

class _Captured {
  final List<RequestOptions> requests = [];
}

({Dio dio, _Captured captured}) _stubDio(
  List<Object?> responses, {
  List<int>? statuses,
}) {
  final captured = _Captured();
  final adapter = _MockHttpAdapter();
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.bullpay.test',
      validateStatus: (status) => status != null && status < 600,
    ),
  )..httpClientAdapter = adapter;
  var index = 0;

  when(() => adapter.fetch(any(), any(), any())).thenAnswer((invocation) async {
    final options = invocation.positionalArguments[0] as RequestOptions;
    captured.requests.add(options);
    final body = responses[index];
    final status = statuses == null ? 200 : statuses[index];
    index += 1;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );
  });

  return (dio: dio, captured: captured);
}

Map<String, dynamic> _capableLookup({
  Object? alias = 'coffee',
  Object? quota = const {'used': 1, 'cap': 1, 'remaining': 0},
  Object? lightningAddressOnline = true,
  bool active = true,
}) {
  return {
    'nym': 'alice',
    'active': active,
    'lightning_address': active ? 'alice@pay2.bull-wallet.com' : null,
    'lightning_address_online': lightningAddressOnline,
    'alias': alias,
    'public_name_policy': bullnymPermanentNamesV1Policy,
    'quota': quota,
  };
}

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  group('GET /version capability', () {
    test(
      'enables only the exact advertised policy and tolerates new keys',
      () async {
        final stub = _stubDio([
          {
            'public_name_policy': bullnymPermanentNamesV1Policy,
            'future_server_field': {'ignored': true},
          },
        ]);
        final facade = BullnymFacade(
          client: BullnymHttpClient.withDio(stub.dio),
        );

        final version = _unwrap(await facade.getVersion());

        expect(version.supportsPermanentNamesV1, isTrue);
        expect(stub.captured.requests.single.method, 'GET');
        expect(stub.captured.requests.single.path, '/version');
      },
    );

    test(
      'missing or unknown policy fails closed without failing the app',
      () async {
        final stub = _stubDio([
          {'version': 'old-server'},
          {'public_name_policy': 'permanent_names_v2'},
        ]);
        final facade = BullnymFacade(
          client: BullnymHttpClient.withDio(stub.dio),
        );

        expect(
          _unwrap(await facade.getVersion()).supportsPermanentNamesV1,
          isFalse,
        );
        expect(
          _unwrap(await facade.getVersion()).supportsPermanentNamesV1,
          isFalse,
        );
      },
    );

    test('invalid policy type is an invalid server response', () async {
      final stub = _stubDio([
        {'public_name_policy': 1},
      ]);
      final facade = BullnymFacade(client: BullnymHttpClient.withDio(stub.dio));

      expect(
        _unwrapFailure(await facade.getVersion()).kind,
        BullnymFailureKind.invalidServerResponse,
      );
    });

    test(
      'capable server reaches first-claim flow when lookup is unregistered',
      () async {
        final stub = _stubDio([
          {'public_name_policy': bullnymPermanentNamesV1Policy},
          {
            'status': 'ERROR',
            'code': 'NymNotFound',
            'reason': 'not registered',
          },
        ]);
        final facade = BullnymFacade(
          client: BullnymHttpClient.withDio(stub.dio),
        );

        final version = _unwrap(await facade.getVersion());
        final lookupFailure = _unwrapFailure(
          await facade.lookupRegistration(npubHex: 'aa' * 32),
        );

        expect(version.supportsPermanentNamesV1, isTrue);
        expect(lookupFailure.code, 'NymNotFound');
        expect(lookupFailure.statusCode, 200);
        expect(stub.captured.requests.map((request) => request.path), [
          '/version',
          '/register/lookup',
        ]);
      },
    );
  });

  group('registration permanent-name status', () {
    test(
      'parses consistent policy, names, status, quota, and unknown keys',
      () async {
        final response = _capableLookup()..['future_server_field'] = true;
        final stub = _stubDio([response]);
        final facade = BullnymFacade(
          client: BullnymHttpClient.withDio(stub.dio),
        );

        final lookup = _unwrap(
          await facade.lookupRegistration(npubHex: 'aa' * 32),
        );
        final status = lookup.publicNameStatus;

        expect(lookup.nym, 'alice');
        expect(lookup.active, isTrue);
        expect(status, isNotNull);
        expect(status!.nym, BullnymPublicName('alice'));
        expect(status.alias, BullnymPublicName('coffee'));
        expect(status.lightningAddressOnline, isTrue);
        expect(status.supportsPermanentNamesV1, isTrue);
        expect(status.quota.used, 1);
        expect(status.quota.cap, 1);
        expect(status.quota.remaining, 0);
      },
    );

    test('parses an explicit null alias as no lifetime alias claim', () async {
      final stub = _stubDio([
        _capableLookup(
          alias: null,
          active: false,
          lightningAddressOnline: false,
        ),
      ]);
      final facade = BullnymFacade(client: BullnymHttpClient.withDio(stub.dio));

      final lookup = _unwrap(
        await facade.lookupRegistration(npubHex: 'aa' * 32),
      );

      expect(lookup.publicNameStatus!.alias, isNull);
      expect(lookup.publicNameStatus!.lightningAddressOnline, isFalse);
    });

    test('permanent-name lookup without legacy active derives liveness from '
        'lightning_address_online', () async {
      // Exact production pay2 body captured 2026-07-16 for a freshly
      // registered permanent name: no legacy `active` field.
      final stub = _stubDio([
        {
          'nym': 'bbe2enopay20260716151742',
          'lightning_address_online': true,
          'alias': null,
          'public_name_policy': 'permanent_names_v1',
          'quota': {'used': 1, 'cap': 1, 'remaining': 0},
        },
      ]);
      final facade = BullnymFacade(client: BullnymHttpClient.withDio(stub.dio));

      final lookup = _unwrap(
        await facade.lookupRegistration(npubHex: 'aa' * 32),
      );
      final status = lookup.publicNameStatus;

      expect(lookup.nym, 'bbe2enopay20260716151742');
      expect(lookup.active, isTrue);
      expect(status, isNotNull);
      expect(status!.nym, BullnymPublicName('bbe2enopay20260716151742'));
      expect(status.alias, isNull);
      expect(status.lightningAddressOnline, isTrue);
      expect(status.supportsPermanentNamesV1, isTrue);
      expect(status.quota.used, 1);
      expect(status.quota.cap, 1);
      expect(status.quota.remaining, 0);
    });

    test('legacy lookup without a policy still requires active', () async {
      final stub = _stubDio([
        {'nym': 'alice'},
      ]);
      final facade = BullnymFacade(client: BullnymHttpClient.withDio(stub.dio));

      expect(
        _unwrapFailure(
          await facade.lookupRegistration(npubHex: 'aa' * 32),
        ).kind,
        BullnymFailureKind.invalidServerResponse,
      );
    });

    test(
      'permanent-name lookup rejects active contradicting liveness',
      () async {
        final stub = _stubDio([
          _capableLookup(active: false, lightningAddressOnline: true),
        ]);
        final facade = BullnymFacade(
          client: BullnymHttpClient.withDio(stub.dio),
        );

        expect(
          _unwrapFailure(
            await facade.lookupRegistration(npubHex: 'aa' * 32),
          ).kind,
          BullnymFailureKind.invalidServerResponse,
        );
      },
    );

    test(
      'old or unknown policy returns legacy state with new status hidden',
      () async {
        final stub = _stubDio([
          {'nym': 'alice', 'active': false},
          {
            ..._capableLookup(),
            'public_name_policy': 'permanent_names_v2',
            'alias': 123,
          },
        ]);
        final facade = BullnymFacade(
          client: BullnymHttpClient.withDio(stub.dio),
        );

        expect(
          _unwrap(
            await facade.lookupRegistration(npubHex: 'aa' * 32),
          ).publicNameStatus,
          isNull,
        );
        expect(
          _unwrap(
            await facade.lookupRegistration(npubHex: 'aa' * 32),
          ).publicNameStatus,
          isNull,
        );
      },
    );

    test('exact policy rejects missing or invalid typed fields', () async {
      final missingAlias = _capableLookup()..remove('alias');
      final missingOnline = _capableLookup()
        ..remove('lightning_address_online');
      final cases = <Map<String, dynamic>>[
        missingAlias,
        missingOnline,
        _capableLookup(alias: ''),
        _capableLookup(alias: 'Alice'),
        _capableLookup(lightningAddressOnline: 'yes'),
        _capableLookup(quota: null),
        _capableLookup(quota: const {'used': 1, 'cap': 1, 'remaining': 1}),
        _capableLookup(active: true, lightningAddressOnline: false),
      ];
      final stub = _stubDio(cases);
      final facade = BullnymFacade(client: BullnymHttpClient.withDio(stub.dio));

      for (var index = 0; index < cases.length; index += 1) {
        final failure = _unwrapFailure(
          await facade.lookupRegistration(npubHex: 'aa' * 32),
        );
        expect(
          failure.kind,
          BullnymFailureKind.invalidServerResponse,
          reason: 'case $index',
        );
      }
    });

    test(
      'register response publishes a validated quota when present',
      () async {
        final stub = _stubDio([
          {
            'nym': 'alice',
            'lightning_address': 'alice@pay2.bull-wallet.com',
            'quota': {'used': 1, 'cap': 1, 'remaining': 0},
          },
        ]);
        final client = BullnymHttpClient.withDio(stub.dio);

        final result = _unwrap(
          await client.register(
            const BullnymRegisterRequest(
              nym: 'alice',
              ctDescriptor: 'ct',
              npubHex: 'npub',
              signatureHex: 'sig',
              timestamp: 1,
            ),
          ),
        );

        expect(result.quota!.remaining, 0);
      },
    );
  });

  group('stable conflict decoding', () {
    test('legacy HTTP 200 NymTaken is normalized to NameTaken', () async {
      final stub = _stubDio([
        {
          'status': 'ERROR',
          'code': 'NymTaken',
          'reason': 'legacy private diagnostic',
        },
      ]);
      final facade = BullnymFacade(client: BullnymHttpClient.withDio(stub.dio));

      final failure = _unwrapFailure(
        await facade.lookupRegistration(npubHex: 'aa' * 32),
      );

      expect(failure.code, 'NameTaken');
      expect(failure.statusCode, 200);
      expect(failure.toString(), isNot(contains('private diagnostic')));
    });

    test(
      'target HTTP 409 NameTaken remains stable and non-retryable',
      () async {
        final stub = _stubDio(
          [
            {
              'status': 'ERROR',
              'code': 'NameTaken',
              'reason': 'target private diagnostic',
            },
          ],
          statuses: [409],
        );
        final facade = BullnymFacade(
          client: BullnymHttpClient.withDio(stub.dio),
        );

        final failure = _unwrapFailure(
          await facade.lookupRegistration(npubHex: 'aa' * 32),
        );

        expect(failure.code, 'NameTaken');
        expect(failure.statusCode, 409);
        expect(failure.retryable, isFalse);
        expect(failure.toString(), isNot(contains('private diagnostic')));
      },
    );

    for (final statusCode in [200, 409]) {
      test('HTTP $statusCode parses owned nym conflict details', () async {
        final stub = _stubDio(
          [
            {
              'status': 'ERROR',
              'code': 'NymAlreadyAssigned',
              'reason': 'do not show this reason',
              'details': {'nym': 'alice', 'domain': 'pay2.bull-wallet.com'},
            },
          ],
          statuses: [statusCode],
        );
        final facade = BullnymFacade(
          client: BullnymHttpClient.withDio(stub.dio),
        );

        final failure = _unwrapFailure(
          await facade.lookupRegistration(npubHex: 'aa' * 32),
        );
        final details = failure.ownedNameDetails as BullnymOwnedNymDetails;

        expect(failure.code, 'NymAlreadyAssigned');
        expect(details.nym, BullnymPublicName('alice'));
        expect(details.domain, 'pay2.bull-wallet.com');
        expect(failure.toString(), isNot(contains('do not show')));
      });

      test('HTTP $statusCode parses owned alias conflict details', () async {
        final stub = _stubDio(
          [
            {
              'status': 'ERROR',
              'code': 'AliasAlreadyAssigned',
              'reason': 'do not show this reason',
              'details': {'alias': 'coffee'},
            },
          ],
          statuses: [statusCode],
        );
        final facade = BullnymFacade(
          client: BullnymHttpClient.withDio(stub.dio),
        );

        final failure = _unwrapFailure(
          await facade.lookupRegistration(npubHex: 'aa' * 32),
        );
        final details = failure.ownedNameDetails as BullnymOwnedAliasDetails;

        expect(failure.code, 'AliasAlreadyAssigned');
        expect(details.alias, BullnymPublicName('coffee'));
        expect(failure.toString(), isNot(contains('do not show')));
      });
    }

    test('optional conflict details may be absent', () async {
      final stub = _stubDio(
        [
          {
            'status': 'ERROR',
            'code': 'AliasAlreadyAssigned',
            'reason': 'already assigned',
          },
        ],
        statuses: [409],
      );
      final facade = BullnymFacade(client: BullnymHttpClient.withDio(stub.dio));

      expect(
        _unwrapFailure(
          await facade.lookupRegistration(npubHex: 'aa' * 32),
        ).ownedNameDetails,
        isNull,
      );
    });

    test('unknown error detail shapes remain forward-compatible', () async {
      final stub = _stubDio([
        {
          'status': 'ERROR',
          'code': 'FutureConflict',
          'reason': 'future diagnostic',
          'details': ['a', 'future', 'shape'],
        },
      ]);
      final facade = BullnymFacade(client: BullnymHttpClient.withDio(stub.dio));

      final failure = _unwrapFailure(
        await facade.lookupRegistration(npubHex: 'aa' * 32),
      );

      expect(failure.code, 'FutureConflict');
      expect(failure.ownedNameDetails, isNull);
    });

    test(
      'malformed typed details fail as an invalid server response',
      () async {
        final stub = _stubDio(
          [
            {
              'status': 'ERROR',
              'code': 'NymAlreadyAssigned',
              'reason': 'already assigned',
              'details': {'nym': ''},
            },
          ],
          statuses: [409],
        );
        final facade = BullnymFacade(
          client: BullnymHttpClient.withDio(stub.dio),
        );

        expect(
          _unwrapFailure(
            await facade.lookupRegistration(npubHex: 'aa' * 32),
          ).kind,
          BullnymFailureKind.invalidServerResponse,
        );
      },
    );
  });

  group('trusted public origin configuration', () {
    test('defaults API and public trust to the production Bullnym origin', () {
      expect(bullnymDefaultBaseUrl, 'https://pay2.bull-wallet.com');
      expect(bullnymDefaultPublicBaseUrl, bullnymDefaultBaseUrl);
    });

    test('accepts a separate HTTPS public origin and local fixture origin', () {
      expect(
        BullnymHttpClient(publicBaseUrl: 'https://public.bullpay.test'),
        isA<BullnymHttpClient>(),
      );
      expect(
        BullnymHttpClient(publicBaseUrl: 'http://127.0.0.1:3000'),
        isA<BullnymHttpClient>(),
      );
    });

    test('rejects arbitrary HTTP and non-origin public URLs', () {
      for (final value in [
        'http://public.bullpay.test',
        'https://user@public.bullpay.test',
        'https://public.bullpay.test/base',
        'https://public.bullpay.test?query=1',
        'https://public.bullpay.test#fragment',
      ]) {
        expect(
          () => BullnymHttpClient(publicBaseUrl: value),
          throwsArgumentError,
          reason: value,
        );
      }
    });
  });
}

T _unwrap<T>(Result<T, BullnymFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError('Expected Ok, got $failure'),
};

BullnymFailure _unwrapFailure<T>(Result<T, BullnymFailure> result) =>
    switch (result) {
      Ok() => throw StateError('Expected Err, got Ok'),
      Err(:final failure) => failure,
    };
