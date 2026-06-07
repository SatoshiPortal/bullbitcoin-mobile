import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/nostr/nostr_keychain_handle.dart';
import 'package:bb_mobile/features/bullnym/application/usecases/delete_bullnym_registration_usecase.dart';
import 'package:bb_mobile/features/bullnym/application/usecases/lookup_bullnym_registration_usecase.dart';
import 'package:bb_mobile/features/bullnym/application/usecases/register_bullnym_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';
import 'package:bb_mobile/features/bullnym/frameworks/bullnym_http_client.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
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
      baseUrl: 'https://bullpay.test',
      validateStatus: (status) => status != null && status < 600,
    ),
  )..httpClientAdapter = adapter;
  var index = 0;

  when(() => adapter.fetch(any(), any(), any())).thenAnswer((inv) async {
    final opts = inv.positionalArguments[0] as RequestOptions;
    captured.requests.add(opts);
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

void main() {
  const timestamp = 1710000000;
  late NostrKeychainHandle handle;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  setUp(() {
    handle = _bullnymAuthHandle();
  });

  test('does not mutate caller-supplied Dio options', () {
    bool customValidateStatus(int? status) => status == 418;
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://bullpay.test',
        connectTimeout: const Duration(milliseconds: 123),
        receiveTimeout: const Duration(milliseconds: 456),
        validateStatus: customValidateStatus,
      ),
    );

    final client = BullnymHttpClient(dio: dio);

    expect(client, isA<BullnymHttpClient>());
    expect(dio.options.baseUrl, 'https://bullpay.test');
    expect(dio.options.connectTimeout, const Duration(milliseconds: 123));
    expect(dio.options.receiveTimeout, const Duration(milliseconds: 456));
    expect(identical(dio.options.validateStatus, customValidateStatus), isTrue);
    expect(dio.options.validateStatus(418), isTrue);
    expect(dio.options.validateStatus(200), isFalse);
  });

  test('posts signed register requests using the proven contract', () async {
    final stub = _stubDio([
      {'nym': 'alice', 'lightning_address': 'alice@bullpay.ca'},
    ]);
    final facade = _facadeForClient(
      BullnymHttpClient(dio: stub.dio),
      nowSecs: () => timestamp,
    );

    final response = await facade.register(
      handle: handle,
      nym: 'alice',
      ctDescriptor: 'ct-desc',
    );

    expect(response.nym, 'alice');
    expect(response.lightningAddress, 'alice@bullpay.ca');
    final request = stub.captured.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/register');
    expect(request.data, {
      'nym': 'alice',
      'ct_descriptor': 'ct-desc',
      'npub': handle.publicKeyHex,
      'signature': isA<String>().having((s) => s.length, 'length', 128),
      'timestamp': timestamp,
    });
    expect(
      (request.data as Map<String, dynamic>).containsKey(
        'verification'
        '_npub',
      ),
      isFalse,
    );
    _expectSignatureValid(
      handle: handle,
      signatureHex:
          (request.data as Map<String, dynamic>)['signature'] as String,
      action: bullpayActionRegister,
      nymOrEmpty: 'alice',
      payloadFields: const ['ct-desc'],
      timestampSecs: timestamp,
    );
  });

  test('deletes registration with a signed delete action', () async {
    final stub = _stubDio([
      {'ok': true},
    ]);
    final facade = _facadeForClient(
      BullnymHttpClient(dio: stub.dio),
      nowSecs: () => timestamp,
    );

    await facade.deleteRegistration(handle: handle, nym: 'alice');

    final request = stub.captured.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, '/register');
    expect(request.data, {
      'nym': 'alice',
      'npub': handle.publicKeyHex,
      'signature': isA<String>().having((s) => s.length, 'length', 128),
      'timestamp': timestamp,
    });
    expect(
      (request.data as Map<String, dynamic>).containsKey('purge'),
      isFalse,
    );
    _expectSignatureValid(
      handle: handle,
      signatureHex:
          (request.data as Map<String, dynamic>)['signature'] as String,
      action: bullpayActionDelete,
      nymOrEmpty: 'alice',
      payloadFields: const [],
      timestampSecs: timestamp,
    );
  });

  test('parses proven lookup response shape', () async {
    final stub = _stubDio([
      {'nym': 'alice', 'active': false},
    ]);
    final facade = _facadeForClient(BullnymHttpClient(dio: stub.dio));

    final response = await facade.lookupRegistration(npubHex: 'aa' * 32);

    expect(response.nym, 'alice');
    expect(response.active, isFalse);
    final request = stub.captured.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/register/lookup');
    expect(request.queryParameters['npub'], 'aa' * 32);
  });

  test('maps backend error responses with diagnostics', () async {
    final stub = _stubDio(
      [
        {'status': 'ERROR', 'code': 'NymReserved', 'reason': 'reserved nym'},
      ],
      statuses: [409],
    );
    final facade = _facadeForClient(BullnymHttpClient(dio: stub.dio));

    expect(
      () => facade.lookupRegistration(npubHex: 'aa' * 32),
      throwsA(
        isA<BullnymException>()
            .having(
              (e) => e.kind,
              'kind',
              BullnymErrorKind.serverRejectedRequest,
            )
            .having((e) => e.code, 'code', 'NymReserved')
            .having(
              (e) => e.diagnosticReason,
              'diagnosticReason',
              'reserved nym',
            )
            .having((e) => e.retryable, 'retryable', false)
            .having((e) => e.statusCode, 'statusCode', 409),
      ),
    );
  });

  test('marks transient backend error envelopes retryable', () async {
    final stub = _stubDio(
      [
        {
          'status': 'ERROR',
          'code': 'TemporarilyUnavailable',
          'reason': 'try later',
        },
      ],
      statuses: [503],
    );
    final facade = _facadeForClient(BullnymHttpClient(dio: stub.dio));

    expect(
      () => facade.lookupRegistration(npubHex: 'aa' * 32),
      throwsA(
        isA<BullnymException>()
            .having(
              (e) => e.kind,
              'kind',
              BullnymErrorKind.serverRejectedRequest,
            )
            .having((e) => e.retryable, 'retryable', true)
            .having((e) => e.statusCode, 'statusCode', 503),
      ),
    );
  });

  test('maps malformed success responses to typed invalid response', () async {
    final stub = _stubDio([
      {'nym': 'alice'},
    ]);
    final facade = _facadeForClient(BullnymHttpClient(dio: stub.dio));

    expect(
      () => facade.register(
        handle: handle,
        nym: 'alice',
        ctDescriptor: 'ct-desc',
      ),
      throwsA(
        isA<BullnymException>().having(
          (e) => e.kind,
          'kind',
          BullnymErrorKind.invalidServerResponse,
        ),
      ),
    );
  });

  test(
    'maps malformed backend error envelopes to typed invalid response',
    () async {
      final stub = _stubDio(
        [
          {'status': 'ERROR', 'code': 'NymReserved'},
        ],
        statuses: [409],
      );
      final facade = _facadeForClient(BullnymHttpClient(dio: stub.dio));

      expect(
        () => facade.lookupRegistration(npubHex: 'aa' * 32),
        throwsA(
          isA<BullnymException>().having(
            (e) => e.kind,
            'kind',
            BullnymErrorKind.invalidServerResponse,
          ),
        ),
      );
    },
  );

  test('builds deployed Bullnym signing message with null separators', () {
    final expected = <int>[];
    void addField(String value) {
      expected.addAll(utf8.encode(value));
      expected.add(0);
    }

    addField(bullpayWireDomain);
    addField(bullpayActionRegister);
    addField('npub');
    addField('alice');
    addField('ct-desc');
    expected.addAll(utf8.encode(timestamp.toString()));

    expect(
      buildBullpaySchnorrMessage(
        action: bullpayActionRegister,
        npubHex: 'npub',
        nymOrEmpty: 'alice',
        payloadFields: const ['ct-desc'],
        timestampSecs: timestamp,
      ),
      expected,
    );
  });
}

BullnymFacade _facadeForClient(
  BullnymHttpClient client, {
  BullnymNowSecs nowSecs = currentBullpayTimestampSecs,
}) {
  return BullnymFacade(
    register: RegisterBullnymUsecase(client: client, nowSecs: nowSecs),
    deleteRegistration: DeleteBullnymRegistrationUsecase(
      client: client,
      nowSecs: nowSecs,
    ),
    lookupRegistration: LookupBullnymRegistrationUsecase(client: client),
  );
}

NostrKeychainHandle _bullnymAuthHandle() {
  return NostrKeychainHandle.deriveFromBip85Path(
    xprvBase58: _zeroMnemonicXprv(),
    hardenedPath: "9000'/2'/1'",
  );
}

String _zeroMnemonicXprv() {
  final mnemonic = bip39.Mnemonic.fromSentence(
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
    bip39.Language.english,
  );
  return bip32.Bip32Keys.fromSeed(Uint8List.fromList(mnemonic.seed)).toBase58();
}

void _expectSignatureValid({
  required NostrKeychainHandle handle,
  required String signatureHex,
  required String action,
  required String nymOrEmpty,
  required List<String> payloadFields,
  required int timestampSecs,
}) {
  final message = buildBullpaySchnorrMessage(
    action: action,
    npubHex: handle.publicKeyHex,
    nymOrEmpty: nymOrEmpty,
    payloadFields: payloadFields,
    timestampSecs: timestampSecs,
  );
  final digest = sha256.convert(message).bytes;
  final pub = ECPublic.fromHex('02${handle.publicKeyHex}');
  expect(
    pub.verifyBip340Signature(
      digest: digest,
      signature: hex.decode(signatureHex),
      tweak: false,
    ),
    isTrue,
  );
}
