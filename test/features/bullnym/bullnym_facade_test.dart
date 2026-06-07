import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/nostr/nostr_keychain_handle.dart';
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
  List<Map<String, dynamic>> responses, {
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
      jsonEncode(body),
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

  test('posts signed register requests with verification npub', () async {
    final stub = _stubDio([
      {
        'nym': 'alice',
        'lightning_address': 'alice@bullpay.ca',
        'quota': {'used': 1, 'cap': 5, 'remaining': 4},
      },
    ]);
    final facade = BullnymFacade(client: BullnymHttpClient(dio: stub.dio));

    final response = await facade.register(
      handle: handle,
      nym: 'alice',
      ctDescriptor: 'ct-desc',
      verificationNpubHex: '03' * 32,
      timestampSecs: timestamp,
    );

    expect(response.nym, 'alice');
    expect(response.lightningAddress, 'alice@bullpay.ca');
    final request = stub.captured.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/register');
    expect(request.data, {
      'nym': 'alice',
      'ct_descriptor': 'ct-desc',
      'verification_npub': '03' * 32,
      'npub': handle.publicKeyHex,
      'signature': isA<String>().having((s) => s.length, 'length', 128),
      'timestamp': timestamp,
    });
    _expectSignatureValid(
      handle: handle,
      signatureHex:
          (request.data as Map<String, dynamic>)['signature'] as String,
      action: bullpayActionRegister,
      nymOrEmpty: 'alice',
      payloadFields: ['ct-desc', '03' * 32],
      timestampSecs: timestamp,
    );
  });

  test('deletes registration with a signed delete action', () async {
    final stub = _stubDio([
      {
        'quota': {'used': 1, 'cap': 5, 'remaining': 4},
      },
    ]);
    final facade = BullnymFacade(client: BullnymHttpClient(dio: stub.dio));

    final response = await facade.deleteRegistration(
      handle: handle,
      nym: 'alice',
      timestampSecs: timestamp,
    );

    expect(response.quota.remaining, 4);
    final request = stub.captured.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, '/register');
    expect((request.data as Map<String, dynamic>)['nym'], 'alice');
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

  test('parses backend lookup response shape', () async {
    final stub = _stubDio([
      {
        'nym': 'alice',
        'active': false,
        'quota': {'used': 2, 'cap': 5, 'remaining': 3},
        'previous_nyms': [
          {'nym': 'alice', 'created_at': '2026-05-10T12:00:00Z'},
        ],
      },
    ]);
    final facade = BullnymFacade(client: BullnymHttpClient(dio: stub.dio));

    final response = await facade.lookupRegistration(npubHex: 'aa' * 32);

    expect(response.active, isFalse);
    expect(response.quota.used, 2);
    expect(response.previousNyms.single.nym, 'alice');
    final request = stub.captured.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/register/lookup');
    expect(request.queryParameters['npub'], 'aa' * 32);
  });

  test('throws backend error responses with status', () async {
    final stub = _stubDio(
      [
        {'status': 'ERROR', 'code': 'NymReserved', 'reason': 'reserved nym'},
      ],
      statuses: [409],
    );
    final facade = BullnymFacade(client: BullnymHttpClient(dio: stub.dio));

    expect(
      () => facade.lookupRegistration(npubHex: 'aa' * 32),
      throwsA(
        isA<BullnymException>()
            .having((e) => e.code, 'code', 'NymReserved')
            .having((e) => e.statusCode, 'statusCode', 409),
      ),
    );
  });

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
    addField('03');
    expected.addAll(utf8.encode(timestamp.toString()));

    expect(
      buildBullpaySchnorrMessage(
        action: bullpayActionRegister,
        npubHex: 'npub',
        nymOrEmpty: 'alice',
        payloadFields: const ['ct-desc', '03'],
        timestampSecs: timestamp,
      ),
      expected,
    );
  });
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
