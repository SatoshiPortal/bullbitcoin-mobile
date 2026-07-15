import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/data/bullnym_http_client.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_recovery_address_actions.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockHttpAdapter extends Mock implements HttpClientAdapter {}

class _Captured {
  final List<RequestOptions> requests = [];
}

({Dio dio, _Captured captured}) _stubDio(List<Object?> responses) {
  final captured = _Captured();
  final adapter = _MockHttpAdapter();
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://bullpay.test',
      validateStatus: (status) => status != null && status < 600,
    ),
  )..httpClientAdapter = adapter;
  var index = 0;

  when(() => adapter.fetch(any(), any(), any())).thenAnswer((invocation) async {
    final options = invocation.positionalArguments[0] as RequestOptions;
    captured.requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(responses[index++]),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  });

  return (dio: dio, captured: captured);
}

List<int> _oracleMessageBytes({
  required String action,
  required String npubHex,
  required List<String> payloadFields,
  required int timestampSecs,
}) {
  final bytes = <int>[];
  for (final value in [
    bullpayWireDomain,
    action,
    npubHex,
    '',
    ...payloadFields,
  ]) {
    bytes
      ..addAll(utf8.encode(value))
      ..add(0);
  }
  bytes.addAll(utf8.encode(timestampSecs.toString()));
  return bytes;
}

void main() {
  const timestamp = 1710000000;
  const npubHex =
      '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
  const btcAddress = 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh';
  late List<String> signedHashes;
  late BullnymAuthSigner signer;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  setUp(() {
    signedHashes = [];
    signer = BullnymAuthSigner(
      npubHex: npubHex,
      signHashHex: (hashHex) {
        signedHashes.add(hashHex);
        return '11' * 64;
      },
    );
  });

  test('pins both identity-wide action layouts byte-exactly', () {
    expect(bullpayActionRecoveryAddressSet, 'recovery-address-set');
    expect(bullpayActionRecoveryAddressGet, 'recovery-address-get');
    expect(buildRecoveryAddressRegistrationPayloadFields(btcAddress), const [
      '1',
      btcAddress,
    ]);
    expect(buildRecoveryAddressLookupPayloadFields(), isEmpty);

    final setMessage = _unwrap(
      buildBullpaySchnorrMessage(
        action: bullpayActionRecoveryAddressSet,
        npubHex: npubHex,
        nymOrEmpty: '',
        payloadFields: const ['1', btcAddress],
        timestampSecs: timestamp,
      ),
    );
    expect(
      setMessage,
      _oracleMessageBytes(
        action: 'recovery-address-set',
        npubHex: npubHex,
        payloadFields: const ['1', btcAddress],
        timestampSecs: timestamp,
      ),
    );
    expect(setMessage.where((byte) => byte == 0), hasLength(6));

    final getMessage = _unwrap(
      buildBullpaySchnorrMessage(
        action: bullpayActionRecoveryAddressGet,
        npubHex: npubHex,
        nymOrEmpty: '',
        payloadFields: const [],
        timestampSecs: timestamp,
      ),
    );
    expect(
      getMessage,
      _oracleMessageBytes(
        action: 'recovery-address-get',
        npubHex: npubHex,
        payloadFields: const [],
        timestampSecs: timestamp,
      ),
    );
    expect(getMessage.where((byte) => byte == 0), hasLength(4));
  });

  test('signed lookup parses a complete private commitment', () async {
    final stub = _stubDio([
      {
        'version': 1,
        'recovery_address_registered': true,
        'btc_address': btcAddress,
        'commitment_version': 3,
        'signed_at_unix': 1709999999,
      },
    ]);
    final facade = BullnymFacade(
      client: BullnymHttpClient.withDio(stub.dio, nowSecs: () => timestamp),
    );

    final value = _unwrap(await facade.lookupRecoveryAddress(signer: signer));

    expect(value.version, bullnymRecoveryAddressContractVersion);
    expect(value.isRegistered, isTrue);
    expect(value.btcAddress, btcAddress);
    expect(value.commitmentVersion, 3);
    expect(value.signedAtUnix, 1709999999);
    final request = stub.captured.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/api/v1/recovery-address');
    expect(request.queryParameters, {
      'npub': npubHex,
      'timestamp': timestamp,
      'signature': '11' * 64,
    });
    expect(signedHashes, [
      sha256
          .convert(
            _oracleMessageBytes(
              action: 'recovery-address-get',
              npubHex: npubHex,
              payloadFields: const [],
              timestampSecs: timestamp,
            ),
          )
          .toString(),
    ]);
  });

  test('signed lookup accepts only the all-null unregistered shape', () async {
    final stub = _stubDio([
      {
        'version': 1,
        'recovery_address_registered': false,
        'btc_address': null,
        'commitment_version': null,
        'signed_at_unix': null,
      },
    ]);
    final facade = BullnymFacade(
      client: BullnymHttpClient.withDio(stub.dio, nowSecs: () => timestamp),
    );

    final value = _unwrap(await facade.lookupRecoveryAddress(signer: signer));

    expect(value.isRegistered, isFalse);
    expect(value.btcAddress, isNull);
    expect(value.commitmentVersion, isNull);
    expect(value.signedAtUnix, isNull);
  });

  test(
    'registration sends no descriptor or key and pins the signed hash',
    () async {
      final stub = _stubDio([
        {
          'version': 1,
          'recovery_address_registered': true,
          'signed_at_unix': timestamp,
        },
      ]);
      final facade = BullnymFacade(
        client: BullnymHttpClient.withDio(stub.dio, nowSecs: () => timestamp),
      );

      final value = _unwrap(
        await facade.registerRecoveryAddress(
          signer: signer,
          btcAddress: btcAddress,
        ),
      );

      expect(value.version, bullnymRecoveryAddressContractVersion);
      expect(value.isRegistered, isTrue);
      expect(value.signedAtUnix, timestamp);
      final request = stub.captured.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/api/v1/recovery-address');
      expect(request.data, {
        'version': 1,
        'npub': npubHex,
        'btc_address': btcAddress,
        'timestamp': timestamp,
        'signature': '11' * 64,
      });
      final keys = (request.data as Map<String, dynamic>).keys;
      expect(keys, isNot(contains('descriptor')));
      expect(keys, isNot(contains('ct_descriptor')));
      expect(keys, isNot(contains('xprv')));
      expect(keys, isNot(contains('private_key')));
      expect(signedHashes, [
        sha256
            .convert(
              _oracleMessageBytes(
                action: 'recovery-address-set',
                npubHex: npubHex,
                payloadFields: const ['1', btcAddress],
                timestampSecs: timestamp,
              ),
            )
            .toString(),
      ]);
    },
  );

  test('rejects malformed lookup combinations and unknown versions', () async {
    for (final response in [
      {
        'version': 1,
        'recovery_address_registered': true,
        'btc_address': null,
        'commitment_version': 1,
        'signed_at_unix': timestamp,
      },
      {
        'version': 1,
        'recovery_address_registered': false,
        'btc_address': btcAddress,
        'commitment_version': null,
        'signed_at_unix': null,
      },
      {
        'version': 2,
        'recovery_address_registered': false,
        'btc_address': null,
        'commitment_version': null,
        'signed_at_unix': null,
      },
    ]) {
      final stub = _stubDio([response]);
      final client = BullnymHttpClient.withDio(
        stub.dio,
        nowSecs: () => timestamp,
      );

      _expectInvalidServerResponse(
        await client.lookupRecoveryAddress(signer: signer),
      );
    }
  });

  test(
    'rejects a registration acknowledgement for different signed bytes',
    () async {
      final stub = _stubDio([
        {
          'version': 1,
          'recovery_address_registered': true,
          'signed_at_unix': timestamp - 1,
        },
      ]);
      final client = BullnymHttpClient.withDio(
        stub.dio,
        nowSecs: () => timestamp,
      );

      _expectInvalidServerResponse(
        await client.registerRecoveryAddress(
          signer: signer,
          btcAddress: btcAddress,
        ),
      );
    },
  );

  test(
    'rejects non-canonical-looking input before signing or network',
    () async {
      final stub = _stubDio(const []);
      final client = BullnymHttpClient.withDio(
        stub.dio,
        nowSecs: () => timestamp,
      );

      final result = await client.registerRecoveryAddress(
        signer: signer,
        btcAddress: ' $btcAddress',
      );

      expect(result, isA<Err<dynamic, BullnymFailure>>());
      final failure = (result as Err<dynamic, BullnymFailure>).failure;
      expect(failure.kind, BullnymFailureKind.invalidInput);
      expect(signedHashes, isEmpty);
      expect(stub.captured.requests, isEmpty);
    },
  );
}

T _unwrap<T>(Result<T, BullnymFailure> result) {
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => fail('Expected Ok, got ${failure.code}'),
  };
}

void _expectInvalidServerResponse<T>(Result<T, BullnymFailure> result) {
  expect(result, isA<Err<T, BullnymFailure>>());
  final failure = (result as Err<T, BullnymFailure>).failure;
  expect(failure.kind, BullnymFailureKind.invalidServerResponse);
}
