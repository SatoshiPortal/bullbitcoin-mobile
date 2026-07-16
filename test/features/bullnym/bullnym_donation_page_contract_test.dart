import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/nostr/nostr_keychain_handle.dart';
import 'package:bb_mobile/features/bullnym/data/bullnym_http_client.dart';
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

// Independent hand-built oracle of the signed byte layout — derived from the
// server's documented `bullpay-la-v2` wire format
// (`src/auth.rs::build_la_v2_message` + `src/donation_page.rs` field builders),
// NOT from the production `buildBullpaySchnorrMessage`. Both the layout equality
// and the signature verification below check against this.
List<int> _oracleMessageBytes({
  required String action,
  required String npubHex,
  required String nymOrEmpty,
  required List<String> payloadFields,
  required int timestampSecs,
}) {
  final bytes = <int>[];
  void addField(String value) {
    bytes.addAll(utf8.encode(value));
    bytes.add(0);
  }

  addField('bullpay-la-v2');
  addField(action);
  addField(npubHex);
  addField(nymOrEmpty);
  for (final field in payloadFields) {
    addField(field);
  }
  bytes.addAll(utf8.encode(timestampSecs.toString()));
  return bytes;
}

Map<String, dynamic> _donationPageView({
  String nym = 'alice',
  bool enabled = true,
  bool isArchived = false,
  String kind = 'payment_page',
}) {
  return {
    'nym': nym,
    'header': 'Tip me',
    'description': 'Support my work',
    'display_currency': 'CAD',
    'website': 'https://example.com',
    'twitter': 'me',
    'instagram': null,
    'kind': kind,
    'enabled': enabled,
    'is_archived': isArchived,
    'avatar_sha256': null,
    'og_sha256': null,
    'public_url': 'https://bullpay.ca/alice',
  };
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

  group('T-DP-SIGN save byte layout', () {
    test('pins the enabled save layout: 7 mandatory + ct_descriptor + kind '
        'LAST, no pos_mode', () {
      final oracle = _oracleMessageBytes(
        action: 'donation-page-save',
        npubHex: 'npub',
        nymOrEmpty: 'alice',
        payloadFields: const [
          'Tip me',
          'Support my work',
          'CAD',
          'https://example.com',
          'me',
          '', // absent instagram signed as empty string, never skipped
          '1', // enabled
          'ct(desc)',
          'payment_page', // kind LAST
        ],
        timestampSecs: timestamp,
      );

      expect(
        buildBullpaySchnorrMessage(
          action: bullpayActionDonationPageSave,
          npubHex: 'npub',
          nymOrEmpty: 'alice',
          payloadFields: const [
            'Tip me',
            'Support my work',
            'CAD',
            'https://example.com',
            'me',
            '',
            '1',
            'ct(desc)',
            'payment_page',
          ],
          timestampSecs: timestamp,
        ),
        oracle,
      );
    });

    test('disabled save signs enabled slot as "0"', () {
      final message = buildBullpaySchnorrMessage(
        action: bullpayActionDonationPageSave,
        npubHex: 'npub',
        nymOrEmpty: 'alice',
        payloadFields: const [
          'Tip me',
          'Support my work',
          'CAD',
          '',
          '',
          '',
          '0',
          'ct(desc)',
          'payment_page',
        ],
        timestampSecs: timestamp,
      );
      // The enabled slot ('0') is the 7th payload field.
      expect(
        utf8.decode(message).contains('\u00000\u0000ct(desc)\u0000'),
        isTrue,
      );
    });

    test('action constant is the deployed wire name', () {
      expect(bullpayActionDonationPageSave, 'donation-page-save');
    });
  });

  group('T-DP-SIGN archive byte layout', () {
    test('pins the archive layout: [kind] only', () {
      final oracle = _oracleMessageBytes(
        action: 'donation-page-archive',
        npubHex: 'npub',
        nymOrEmpty: 'alice',
        payloadFields: const ['payment_page'],
        timestampSecs: timestamp,
      );

      expect(
        buildBullpaySchnorrMessage(
          action: bullpayActionDonationPageArchive,
          npubHex: 'npub',
          nymOrEmpty: 'alice',
          payloadFields: const ['payment_page'],
          timestampSecs: timestamp,
        ),
        oracle,
      );
      expect(bullpayActionDonationPageArchive, 'donation-page-archive');
    });
  });

  group('T-DP-CLIENT save', () {
    test('PUTs the documented body and signs the exact save layout', () async {
      final stub = _stubDio([_donationPageView()]);
      final facade = _facadeForClient(
        BullnymHttpClient.withDio(stub.dio),
        nowSecs: () => timestamp,
      );

      final page = await facade.saveDonationPage(
        signer: signer,
        nym: 'alice',
        ctDescriptor: 'ct(desc)',
        header: 'Tip me',
        description: 'Support my work',
        displayCurrency: 'CAD',
        website: 'https://example.com',
        twitter: 'me',
        instagram: '',
        enabled: true,
        kind: 'payment_page',
      );

      expect(page.nym, 'alice');
      expect(page.publicUrl, 'https://bullpay.ca/alice');

      final request = stub.captured.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/donation-page');
      final body = request.data as Map<String, dynamic>;
      expect(body.keys.toSet(), {
        'nym',
        'npub',
        'ct_descriptor',
        'header',
        'description',
        'display_currency',
        'website',
        'twitter',
        'instagram',
        'enabled',
        'kind',
        'timestamp',
        'signature',
      });
      expect(body.containsKey('pos_mode'), isFalse);
      expect(body['ct_descriptor'], 'ct(desc)');
      expect(body['kind'], 'payment_page');
      expect(body['enabled'], true);
      expect(body['instagram'], '');

      _expectSignatureValid(
        handle: handle,
        signatureHex: body['signature'] as String,
        action: bullpayActionDonationPageSave,
        nymOrEmpty: 'alice',
        payloadFields: const [
          'Tip me',
          'Support my work',
          'CAD',
          'https://example.com',
          'me',
          '',
          '1',
          'ct(desc)',
          'payment_page',
        ],
        timestampSecs: timestamp,
      );
    });
  });

  group('T-DP-CLIENT archive', () {
    test('DELETEs the documented body with kind and signs [kind]', () async {
      final stub = _stubDio([_donationPageView(isArchived: true)]);
      final facade = _facadeForClient(
        BullnymHttpClient.withDio(stub.dio),
        nowSecs: () => timestamp,
      );

      final page = await facade.archiveDonationPage(
        signer: signer,
        nym: 'alice',
        kind: 'payment_page',
      );

      expect(page.isArchived, isTrue);
      final request = stub.captured.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, '/donation-page');
      final body = request.data as Map<String, dynamic>;
      expect(body.keys.toSet(), {
        'nym',
        'npub',
        'kind',
        'timestamp',
        'signature',
      });
      expect(body.containsKey('pos_mode'), isFalse);
      expect(body['kind'], 'payment_page');

      _expectSignatureValid(
        handle: handle,
        signatureHex: body['signature'] as String,
        action: bullpayActionDonationPageArchive,
        nymOrEmpty: 'alice',
        payloadFields: const ['payment_page'],
        timestampSecs: timestamp,
      );
    });
  });

  group('T-DP-CLIENT get', () {
    test(
      'GETs the kind-scoped path and parses the view (no ct_descriptor)',
      () async {
        final stub = _stubDio([_donationPageView()]);
        final facade = _facadeForClient(BullnymHttpClient.withDio(stub.dio));

        final page = await facade.getDonationPage(
          nym: 'alice',
          kind: 'payment_page',
        );

        expect(page.header, 'Tip me');
        expect(page.displayCurrency, 'CAD');
        expect(page.instagram, isNull);
        expect(page.posMode, isFalse);
        expect(page.enabled, isTrue);
        expect(page.isArchived, isFalse);
        final request = stub.captured.requests.single;
        expect(request.method, 'GET');
        expect(request.path, '/donation-page/alice');
        expect(request.queryParameters['kind'], 'payment_page');
      },
    );

    test('derives posMode from kind=pos without a pos_mode field', () async {
      final stub = _stubDio([_donationPageView(kind: 'pos')]);
      final facade = _facadeForClient(BullnymHttpClient.withDio(stub.dio));

      final page = await facade.getDonationPage(nym: 'alice', kind: 'pos');

      expect(page.kind, bullnymDonationPageKindPos);
      expect(page.posMode, isTrue);
      final request = stub.captured.requests.single;
      expect(request.queryParameters['kind'], bullnymDonationPageKindPos);
    });

    test('rejects a donation-page view missing kind', () async {
      final view = _donationPageView()..remove('kind');
      final stub = _stubDio([view]);
      final facade = _facadeForClient(BullnymHttpClient.withDio(stub.dio));

      expect(
        () => facade.getDonationPage(nym: 'alice', kind: 'payment_page'),
        throwsA(
          isA<BullnymException>().having(
            (e) => e.kind,
            'kind',
            BullnymErrorKind.invalidServerResponse,
          ),
        ),
      );
    });

    test('maps DonationPageNotFound envelope to a typed rejection', () async {
      final stub = _stubDio([
        {
          'status': 'ERROR',
          'code': 'DonationPageNotFound',
          'reason': 'no donation page for alice',
        },
      ]);
      final facade = _facadeForClient(BullnymHttpClient.withDio(stub.dio));

      expect(
        () => facade.getDonationPage(nym: 'alice', kind: 'payment_page'),
        throwsA(
          isA<BullnymException>()
              .having(
                (e) => e.kind,
                'kind',
                BullnymErrorKind.serverRejectedRequest,
              )
              .having((e) => e.code, 'code', 'DonationPageNotFound'),
        ),
      );
    });

    test(
      'surfaces AuthError delivered as HTTP 401 with the envelope',
      () async {
        final stub = _stubDio(
          [
            {
              'status': 'ERROR',
              'code': 'AuthError',
              'reason': 'signature verification failed',
            },
          ],
          statuses: [401],
        );
        final facade = _facadeForClient(
          BullnymHttpClient.withDio(stub.dio),
          nowSecs: () => timestamp,
        );

        expect(
          () => facade.saveDonationPage(
            signer: signer,
            nym: 'alice',
            ctDescriptor: 'ct(desc)',
            header: 'Tip me',
            description: 'Support my work',
            displayCurrency: 'CAD',
            website: '',
            twitter: '',
            instagram: '',
            enabled: true,
            kind: 'payment_page',
          ),
          throwsA(
            isA<BullnymException>()
                .having(
                  (e) => e.kind,
                  'kind',
                  BullnymErrorKind.serverRejectedRequest,
                )
                .having((e) => e.code, 'code', 'AuthError')
                .having((e) => e.statusCode, 'statusCode', 401),
          ),
        );
      },
    );
  });

  group('T-DP-CLIENT supported currencies', () {
    test('parses the currencies list', () async {
      final stub = _stubDio([
        {
          'currencies': [
            {'code': 'CAD', 'precision': 2},
            {'code': 'COP', 'precision': 0},
          ],
        },
      ]);
      final facade = _facadeForClient(BullnymHttpClient.withDio(stub.dio));

      final currencies = await facade.getSupportedCurrencies();

      expect(currencies.currencies.map((c) => c.code), ['CAD', 'COP']);
      expect(currencies.currencies.last.precision, 0);
      final request = stub.captured.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/v1/supported-currencies');
    });

    test('throws on a missing currencies key', () async {
      final stub = _stubDio([
        {'unexpected': true},
      ]);
      final facade = _facadeForClient(BullnymHttpClient.withDio(stub.dio));

      expect(
        facade.getSupportedCurrencies,
        throwsA(
          isA<BullnymException>().having(
            (e) => e.kind,
            'kind',
            BullnymErrorKind.invalidServerResponse,
          ),
        ),
      );
    });
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
  final message = _oracleMessageBytes(
    action: action,
    npubHex: handle.publicKeyHex,
    nymOrEmpty: nymOrEmpty,
    payloadFields: payloadFields,
    timestampSecs: timestampSecs,
  );
  final digest = sha256.convert(message).bytes;
  final publicKey = ECPublic.fromHex('02${handle.publicKeyHex}');
  expect(
    publicKey.verifyBip340Signature(
      digest: digest,
      signature: hex.decode(signatureHex),
      tweak: false,
    ),
    isTrue,
  );
}
