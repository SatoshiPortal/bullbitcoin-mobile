import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/nostr/nostr_keychain_handle.dart';
import 'package:bb_mobile/features/bullnym/data/bullnym_http_client.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_actions.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';
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
  late BullnymAuthSigner signer;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  setUp(() {
    handle = _bullnymAuthHandle();
    signer = _signerFromHandle(handle);
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

    final client = BullnymHttpClient.withDio(dio);

    expect(client, isA<BullnymHttpClient>());
    expect(dio.options.baseUrl, 'https://bullpay.test');
    expect(dio.options.connectTimeout, const Duration(milliseconds: 123));
    expect(dio.options.receiveTimeout, const Duration(milliseconds: 456));
    expect(identical(dio.options.validateStatus, customValidateStatus), isTrue);
    expect(dio.options.validateStatus(418), isTrue);
    expect(dio.options.validateStatus(200), isFalse);
  });

  test('uses caller-supplied Bullnym base URL', () {
    final client = BullnymHttpClient(baseUrl: 'https://custom.bullnym.test');

    expect(client.baseUrl, 'https://custom.bullnym.test');
  });

  test('rejects invalid Bullnym base URLs', () {
    expect(() => BullnymHttpClient(baseUrl: ''), throwsArgumentError);
    expect(
      () => BullnymHttpClient(baseUrl: 'custom.bullnym.test'),
      throwsArgumentError,
    );
    expect(
      () => BullnymHttpClient(baseUrl: 'ftp://custom.bullnym.test'),
      throwsArgumentError,
    );
    expect(
      () => BullnymHttpClient(baseUrl: 'http://custom.bullnym.test'),
      throwsArgumentError,
    );
  });

  test('allows http only for local Bullnym fixtures', () {
    final client = BullnymHttpClient(baseUrl: 'http://localhost:3000');

    expect(client.baseUrl, 'http://localhost:3000');
  });

  test('accepts the exact Rust backup mutation response shape', () async {
    final ciphertext = AuthenticatedBackupCiphertext(
      base64.encode(List<int>.filled(64, 7)),
    );
    final ciphertextHash = sha256
        .convert(base64.decode(ciphertext.value))
        .toString();
    final storedEtag = computeWalletBackupEtag(
      stream: BullnymBackupStream.keychainManifest,
      npubHex: signer.npubHex,
      generation: 1,
      ciphertextSha256: ciphertextHash,
    );
    final deletedEtag = computeWalletBackupEtag(
      stream: BullnymBackupStream.keychainManifest,
      npubHex: signer.npubHex,
      generation: 2,
      ciphertextSha256: '',
    );
    final stub = _stubDio([
      {'version': 1, 'generation': 1, 'etag': storedEtag},
      {'version': 1, 'generation': 2, 'etag': deletedEtag},
    ]);
    final facade = _facadeForClient(
      BullnymHttpClient.withDio(stub.dio),
      nowSecs: () => timestamp,
    );

    final stored = await facade.storeBackup(
      signer: signer,
      stream: BullnymBackupStream.keychainManifest,
      currentHead: BullnymBackupHead.absent(generation: 0, etag: null),
      ciphertext: ciphertext,
    );
    final deleted = await facade.deleteBackup(
      signer: signer,
      stream: BullnymBackupStream.keychainManifest,
      currentHead: BullnymBackupHead.present(
        generation: stored.generation,
        etag: stored.etag,
        ciphertext: ciphertext,
        ciphertextSha256: ciphertextHash,
        updatedAtSecs: timestamp,
      ),
    );

    expect(stored.etag, storedEtag);
    expect(deleted!.etag, deletedEtag);
  });

  test(
    'verifies fetched ciphertext integrity and deterministic ETag',
    () async {
      final ciphertext = base64.encode(List<int>.filled(64, 9));
      final ciphertextHash = sha256
          .convert(base64.decode(ciphertext))
          .toString();
      final etag = computeWalletBackupEtag(
        stream: BullnymBackupStream.keychainManifest,
        npubHex: signer.npubHex,
        generation: 4,
        ciphertextSha256: ciphertextHash,
      );
      final stub = _stubDio([
        {
          'version': 1,
          'found': true,
          'generation': 4,
          'etag': etag,
          'ciphertext': ciphertext,
          'ciphertext_sha256': ciphertextHash,
          'ciphertext_bytes': 64,
          'updated_at': timestamp,
        },
      ]);
      final facade = _facadeForClient(
        BullnymHttpClient.withDio(stub.dio),
        nowSecs: () => timestamp,
      );

      final head = await facade.fetchBackup(
        signer: signer,
        stream: BullnymBackupStream.keychainManifest,
      );

      expect(head.generation, 4);
      expect(head.etag, etag);
      expect(head.ciphertext!.value, ciphertext);
    },
  );

  test('rejects a fetched head whose ETag is not server-deterministic', () {
    final ciphertext = base64.encode(List<int>.filled(64, 9));
    final ciphertextHash = sha256.convert(base64.decode(ciphertext)).toString();
    final stub = _stubDio([
      {
        'version': 1,
        'found': true,
        'generation': 4,
        'etag': '00' * 32,
        'ciphertext': ciphertext,
        'ciphertext_sha256': ciphertextHash,
        'ciphertext_bytes': 64,
        'updated_at': timestamp,
      },
    ]);
    final facade = _facadeForClient(
      BullnymHttpClient.withDio(stub.dio),
      nowSecs: () => timestamp,
    );

    expect(
      () => facade.fetchBackup(
        signer: signer,
        stream: BullnymBackupStream.keychainManifest,
      ),
      throwsA(isA<BullnymInvalidServerResponseException>()),
    );
  });

  test(
    'posts signed register requests using the harness-backed contract',
    () async {
      final stub = _stubDio([
        {'nym': 'alice', 'lightning_address': 'alice@bullpay.ca'},
      ]);
      final facade = _facadeForClient(
        BullnymHttpClient.withDio(stub.dio),
        nowSecs: () => timestamp,
      );

      final response = await facade.register(
        signer: signer,
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
        'npub': signer.npubHex,
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
    },
  );

  test('deletes registration with a signed delete action', () async {
    final stub = _stubDio([
      {'ok': true},
    ]);
    final facade = _facadeForClient(
      BullnymHttpClient.withDio(stub.dio),
      nowSecs: () => timestamp,
    );

    await facade.deleteRegistration(signer: signer, nym: 'alice');

    final request = stub.captured.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, '/register');
    expect(request.data, {
      'nym': 'alice',
      'npub': signer.npubHex,
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

  test('accepts empty successful delete responses', () async {
    final stub = _stubDio([null], statuses: [204]);
    final facade = _facadeForClient(
      BullnymHttpClient.withDio(stub.dio),
      nowSecs: () => timestamp,
    );

    await facade.deleteRegistration(signer: signer, nym: 'alice');

    final request = stub.captured.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, '/register');
  });

  test('parses documented lookup response shape', () async {
    final stub = _stubDio([
      {'nym': 'alice', 'active': false},
    ]);
    final facade = _facadeForClient(BullnymHttpClient.withDio(stub.dio));

    final response = await facade.lookupRegistration(npubHex: 'aa' * 32);

    expect(response.nym, 'alice');
    expect(response.active, isFalse);
    expect(response.lightningAddress, isNull);
    final request = stub.captured.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/register/lookup');
    expect(request.queryParameters['npub'], 'aa' * 32);
  });

  test('rejects malformed lookup npub before network request', () async {
    final stub = _stubDio([
      {'nym': 'alice', 'active': false},
    ]);
    final facade = _facadeForClient(BullnymHttpClient.withDio(stub.dio));

    expect(
      () => facade.lookupRegistration(npubHex: 'not-hex'),
      throwsA(
        isA<BullnymException>()
            .having((e) => e.kind, 'kind', BullnymErrorKind.invalidInput)
            .having((e) => e.retryable, 'retryable', false),
      ),
    );
    expect(stub.captured.requests, isEmpty);
  });

  test('parses canonical lookup Lightning Address when returned', () async {
    final stub = _stubDio([
      {'nym': 'alice', 'active': true, 'lightning_address': 'alice@bullpay.ca'},
    ]);
    final facade = _facadeForClient(BullnymHttpClient.withDio(stub.dio));

    final response = await facade.lookupRegistration(npubHex: 'aa' * 32);

    expect(response.nym, 'alice');
    expect(response.active, isTrue);
    expect(response.lightningAddress, 'alice@bullpay.ca');
  });

  test('maps backend error responses with diagnostics', () async {
    final stub = _stubDio(
      [
        {'status': 'ERROR', 'code': 'NymReserved', 'reason': 'reserved nym'},
      ],
      statuses: [409],
    );
    final facade = _facadeForClient(BullnymHttpClient.withDio(stub.dio));

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
    final facade = _facadeForClient(BullnymHttpClient.withDio(stub.dio));

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
    final facade = _facadeForClient(BullnymHttpClient.withDio(stub.dio));

    expect(
      () => facade.register(
        signer: signer,
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

  test('rejects null separators in signed register fields', () async {
    final stub = _stubDio([
      {'nym': 'alice', 'lightning_address': 'alice@bullpay.ca'},
    ]);
    final facade = _facadeForClient(
      BullnymHttpClient.withDio(stub.dio),
      nowSecs: () => timestamp,
    );

    expect(
      () => facade.register(
        signer: signer,
        nym: 'ali\u0000ce',
        ctDescriptor: 'ct-desc',
      ),
      throwsA(
        isA<BullnymException>()
            .having((e) => e.kind, 'kind', BullnymErrorKind.invalidInput)
            .having((e) => e.retryable, 'retryable', false),
      ),
    );
    expect(stub.captured.requests, isEmpty);
  });

  test('rejects null separators in signed descriptor fields', () async {
    final stub = _stubDio([
      {'nym': 'alice', 'lightning_address': 'alice@bullpay.ca'},
    ]);
    final facade = _facadeForClient(
      BullnymHttpClient.withDio(stub.dio),
      nowSecs: () => timestamp,
    );

    expect(
      () => facade.register(
        signer: signer,
        nym: 'alice',
        ctDescriptor: 'ct\u0000desc',
      ),
      throwsA(isA<BullnymException>()),
    );
    expect(stub.captured.requests, isEmpty);
  });

  test('does not expose signer exception text on signing failure', () async {
    final stub = _stubDio([
      {'nym': 'alice', 'lightning_address': 'alice@bullpay.ca'},
    ]);
    final facade = _facadeForClient(
      BullnymHttpClient.withDio(stub.dio),
      nowSecs: () => timestamp,
    );
    final throwingSigner = BullnymAuthSigner(
      npubHex: signer.npubHex,
      signHashHex: (_) => throw Exception('xprv-secret-leak'),
    );

    await expectLater(
      () => facade.register(
        signer: throwingSigner,
        nym: 'alice',
        ctDescriptor: 'ct-desc',
      ),
      throwsA(
        isA<BullnymException>()
            .having((e) => e.kind, 'kind', BullnymErrorKind.signingFailed)
            .having(
              (e) => e.diagnosticReason,
              'diagnosticReason',
              isNot(contains('xprv-secret-leak')),
            )
            .having(
              (e) => e.toString(),
              'toString',
              isNot(contains('xprv-secret-leak')),
            ),
      ),
    );
    expect(stub.captured.requests, isEmpty);
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
      final facade = _facadeForClient(BullnymHttpClient.withDio(stub.dio));

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

  test('builds Bullpay LA v2 signing message with null separators', () {
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
  int Function() nowSecs = currentBullpayTimestampSecs,
}) {
  return BullnymFacade(client: client, nowSecs: nowSecs);
}

NostrKeychainHandle _bullnymAuthHandle() {
  return NostrKeychainHandle.deriveFromBip85Path(
    xprvBase58: _zeroMnemonicXprv(),
    hardenedPath: "9000'/2'/1'",
  );
}

BullnymAuthSigner _signerFromHandle(NostrKeychainHandle handle) {
  return BullnymAuthSigner(
    npubHex: handle.publicKeyHex,
    signHashHex: handle.signHashHex,
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
