import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/nostr/nostr_keychain_handle.dart';
import 'package:bb_mobile/features/bullnym/data/bullnym_http_client.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice_actions.dart';
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
// (`src/auth.rs::build_la_v2_message` + `src/invoice.rs` field builders), NOT
// from the production `buildBullpaySchnorrMessage`.
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

Map<String, dynamic> _statusView({String status = 'unpaid'}) {
  return {
    'status': status,
    'pricing_mode': 'sat',
    'settlement_status': 'none',
    'amount_sat': 25000,
    'fiat_amount_minor': null,
    'fiat_currency': null,
    'remaining_amount_sat': 25000,
    'payment_tolerance_sat': 0,
    'rate_minor_per_btc': null,
    'rate_locks_until_unix': 1710000000,
    'expires_at_unix': 1710086400,
    'paid_via': null,
    'paid_at_unix': null,
    'paid_amount_sat': null,
    'lightning_pr': null,
    'liquid_address': 'lq1qtest',
    'bitcoin_address': null,
    'bitcoin_direct_observations': [],
    'bitcoin_chain_address': null,
    'bitcoin_chain_bip21': null,
    'accept_btc': false,
    'accept_ln': true,
    'accept_liquid': true,
    // A future server field the older binary must ignore (tolerant reader).
    'some_unknown_future_field': 'ignored',
  };
}

Map<String, dynamic> _listItemView({String? nymOwner, bool paid = false}) {
  return {
    'id': 'inv-1',
    'nym_owner': nymOwner,
    'origin': 'wallet',
    'status': paid ? 'paid' : 'unpaid',
    'pricing_mode': 'sat',
    'settlement_status': 'none',
    'amount_sat': 25000,
    'remaining_amount_sat': paid ? 0 : 25000,
    'fiat_amount_minor': null,
    'fiat_currency': null,
    'public_description': 'Consulting',
    'recipient_name': 'Acme',
    'invoice_number': 'INV-042',
    'accept_btc': false,
    'accept_ln': true,
    'accept_liquid': true,
    'bitcoin_address': null,
    'liquid_address': 'lq1qtest',
    'created_at_unix': 1710000000,
    'expires_at_unix': 1710086400,
    'paid_via': paid ? 'liquid' : null,
    'paid_at_unix': paid ? 1710001000 : null,
    'paid_amount_sat': paid ? 25000 : null,
    'extra_unknown_key': true,
  };
}

BullnymCreateInvoiceFields _lnLiquidFields() {
  return const BullnymCreateInvoiceFields(
    amountSat: 25000,
    acceptBtc: false,
    acceptLn: true,
    acceptLiquid: true,
    liquidAddress: 'lq1qtest',
    liquidBlindingKeyHex: 'ab12cd',
    expiresAtUnix: 1710086400,
  );
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

  group('T-INV-SIGN invoice-create byte layout', () {
    test('action constant is the deployed wire name', () {
      expect(bullpayActionInvoiceCreate, 'invoice-create');
    });

    test(
      'pins the unlinked 13-field layout: all fields present, empties as "", '
      'booleans true/false, nym slot empty',
      () {
        // Fiat-denominated, LN+Liquid, no BTC — so amount_sat is empty, fiat
        // fields present, bitcoin_address empty. Hand-derived oracle.
        final fields = const BullnymCreateInvoiceFields(
          fiatAmountMinor: 1050,
          fiatCurrency: 'CAD',
          publicDescription: 'Consulting',
          recipientName: 'Acme',
          invoiceNumber: 'INV-042',
          acceptBtc: false,
          acceptLn: true,
          acceptLiquid: true,
          liquidAddress: 'lq1qtest',
          liquidBlindingKeyHex: 'ab12cd',
          expiresAtUnix: 1710086400,
        );
        final oracle = _oracleMessageBytes(
          action: 'invoice-create',
          npubHex: 'npub',
          nymOrEmpty: '',
          payloadFields: const [
            '', // amount_sat empty (fiat-denominated)
            '1050', // fiat_amount_minor
            'CAD', // fiat_currency
            'Consulting', // public_description
            'Acme', // recipient_name
            'INV-042', // invoice_number
            'false', // accept_btc
            'true', // accept_ln
            'true', // accept_liquid
            '', // bitcoin_address empty (no BTC rail)
            'lq1qtest', // liquid_address
            'ab12cd', // liquid_blinding_key_hex
            '1710086400', // expires_at_unix
          ],
          timestampSecs: timestamp,
        );

        expect(
          buildBullpaySchnorrMessage(
            action: bullpayActionInvoiceCreate,
            npubHex: 'npub',
            nymOrEmpty: '',
            payloadFields: buildInvoiceCreatePayloadFields(fields),
            timestampSecs: timestamp,
          ),
          oracle,
        );
        expect(buildInvoiceCreatePayloadFields(fields).length, 13);
      },
    );

    test('sat-denominated omitted-optionals still emit all 13 fields', () {
      final fields = const BullnymCreateInvoiceFields(
        amountSat: 25000,
        acceptBtc: true,
        acceptLn: false,
        acceptLiquid: false,
        bitcoinAddress: 'bc1qtest',
        expiresAtUnix: 1710086400,
      );
      expect(buildInvoiceCreatePayloadFields(fields), const [
        '25000',
        '', // fiat_amount_minor
        '', // fiat_currency
        '', // public_description
        '', // recipient_name
        '', // invoice_number
        'true', // accept_btc
        'false', // accept_ln
        'false', // accept_liquid
        'bc1qtest',
        '', // liquid_address
        '', // liquid_blinding_key_hex
        '1710086400',
      ]);
    });

    test('linked variant signs the nym in the nym slot', () {
      final oracle = _oracleMessageBytes(
        action: 'invoice-create',
        npubHex: 'npub',
        nymOrEmpty: 'alice',
        payloadFields: buildInvoiceCreatePayloadFields(_lnLiquidFields()),
        timestampSecs: timestamp,
      );
      expect(
        buildBullpaySchnorrMessage(
          action: bullpayActionInvoiceCreate,
          npubHex: 'npub',
          nymOrEmpty: 'alice',
          payloadFields: buildInvoiceCreatePayloadFields(_lnLiquidFields()),
          timestampSecs: timestamp,
        ),
        oracle,
      );
    });
  });

  group('T-INV-SIGN invoice-cancel byte layout', () {
    test('pins the cancel layout: [invoice_id] only, nym slot empty', () {
      expect(bullpayActionInvoiceCancel, 'invoice-cancel');
      final oracle = _oracleMessageBytes(
        action: 'invoice-cancel',
        npubHex: 'npub',
        nymOrEmpty: '',
        payloadFields: const ['inv-1'],
        timestampSecs: timestamp,
      );
      expect(
        buildBullpaySchnorrMessage(
          action: bullpayActionInvoiceCancel,
          npubHex: 'npub',
          nymOrEmpty: '',
          payloadFields: buildInvoiceCancelPayloadFields('inv-1'),
          timestampSecs: timestamp,
        ),
        oracle,
      );
    });
  });

  group('T-INV-SIGN invoice-list byte layout', () {
    test('pins the list layout: [page,pageSize,status], nym ALWAYS empty', () {
      expect(bullpayActionInvoiceList, 'invoice-list');
      final oracle = _oracleMessageBytes(
        action: 'invoice-list',
        npubHex: 'npub',
        nymOrEmpty: '',
        payloadFields: const ['1', '100', ''],
        timestampSecs: timestamp,
      );
      expect(
        buildBullpaySchnorrMessage(
          action: bullpayActionInvoiceList,
          npubHex: 'npub',
          nymOrEmpty: '',
          payloadFields: buildInvoiceListPayloadFields(page: 1, pageSize: 100),
          timestampSecs: timestamp,
        ),
        oracle,
      );
    });

    test('status filter fills the third field', () {
      expect(
        buildInvoiceListPayloadFields(page: 2, pageSize: 50, status: 'paid'),
        const ['2', '50', 'paid'],
      );
    });
  });

  group('T-INV-DTO parse round-trips', () {
    test('status shape parses and ignores unknown keys (tolerant reader)', () {
      final client = BullnymHttpClient.withDio(
        _stubDio([_statusView(status: 'paid')]).dio,
      );
      expect(
        client.getInvoiceStatus(invoiceId: 'inv-1'),
        completion(
          isA<BullnymInvoiceStatus>()
              .having((s) => s.status, 'status', 'paid')
              .having((s) => s.liquidAddress, 'liquidAddress', 'lq1qtest')
              .having((s) => s.acceptLiquid, 'acceptLiquid', true),
        ),
      );
    });

    test('list shape parses pageSize rename, null nym_owner and paid_* '
        'optionals', () async {
      final stub = _stubDio([
        {
          'invoices': [_listItemView(), _listItemView(paid: true)],
          'page': 1,
          'pageSize': 100,
          'has_more': false,
        },
      ]);
      final client = BullnymHttpClient.withDio(stub.dio, nowSecs: () => timestamp);
      final result = await client.listInvoices(
        signer: signer,
        page: 1,
        pageSize: 100,
      );
      expect(result.pageSize, 100);
      expect(result.hasMore, isFalse);
      expect(result.invoices.first.nymOwner, isNull);
      expect(result.invoices.first.paidAtUnix, isNull);
      expect(result.invoices.last.status, 'paid');
      expect(result.invoices.last.paidVia, 'liquid');
    });
  });

  group('T-INV-CLIENT create', () {
    test('POSTs the unlinked body and signs the exact 13-field layout',
        () async {
      final stub = _stubDio([
        {'invoice_id': 'inv-1', 'share_url': 'https://bullpay.ca/invoice/inv-1'},
      ]);
      final client = BullnymHttpClient.withDio(
        stub.dio,
        nowSecs: () => timestamp,
      );

      final response = await client.createInvoice(
        signer: signer,
        fields: _lnLiquidFields(),
      );

      expect(response.invoiceId, 'inv-1');
      expect(response.shareUrl, 'https://bullpay.ca/invoice/inv-1');

      final request = stub.captured.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/invoices');
      final body = request.data as Map<String, dynamic>;
      expect(body['npub'], handle.publicKeyHex);
      expect(body['accept_ln'], true);
      expect(body['accept_liquid'], true);
      expect(body['accept_btc'], false);
      expect(body['liquid_address'], 'lq1qtest');
      expect(body['liquid_blinding_key_hex'], 'ab12cd');

      _expectSignatureValid(
        handle: handle,
        signatureHex: body['signature'] as String,
        action: bullpayActionInvoiceCreate,
        nymOrEmpty: '',
        payloadFields: buildInvoiceCreatePayloadFields(_lnLiquidFields()),
        timestampSecs: timestamp,
      );
    });

    test('maps the InvalidAmount envelope to a typed rejection', () {
      final stub = _stubDio([
        {
          'status': 'ERROR',
          'code': 'InvalidAmount',
          'reason': 'amount must be exactly one of sat or fiat',
        },
      ]);
      final client = BullnymHttpClient.withDio(
        stub.dio,
        nowSecs: () => timestamp,
      );
      expect(
        () => client.createInvoice(signer: signer, fields: _lnLiquidFields()),
        throwsA(
          isA<BullnymException>().having((e) => e.code, 'code', 'InvalidAmount'),
        ),
      );
    });
  });

  group('T-INV-CLIENT cancel', () {
    test('DELETEs the id path with npub+ts+sig and signs [id]', () async {
      final stub = _stubDio([
        {'invoice_id': 'inv-1', 'status': 'cancelled'},
      ]);
      final client = BullnymHttpClient.withDio(
        stub.dio,
        nowSecs: () => timestamp,
      );

      final response = await client.cancelInvoice(
        signer: signer,
        invoiceId: 'inv-1',
      );
      expect(response.status, 'cancelled');

      final request = stub.captured.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, '/api/v1/invoices/inv-1');
      final body = request.data as Map<String, dynamic>;
      expect(body.keys.toSet(), {'npub', 'timestamp', 'signature'});

      _expectSignatureValid(
        handle: handle,
        signatureHex: body['signature'] as String,
        action: bullpayActionInvoiceCancel,
        nymOrEmpty: '',
        payloadFields: buildInvoiceCancelPayloadFields('inv-1'),
        timestampSecs: timestamp,
      );
    });
  });

  group('T-INV-CLIENT list', () {
    test('GETs /api/v1/invoices with signed query and empty-nym signature',
        () async {
      final stub = _stubDio([
        {'invoices': [], 'page': 1, 'pageSize': 100, 'has_more': false},
      ]);
      final client = BullnymHttpClient.withDio(
        stub.dio,
        nowSecs: () => timestamp,
      );

      await client.listInvoices(signer: signer, page: 1, pageSize: 100);

      final request = stub.captured.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/v1/invoices');
      expect(request.queryParameters['npub'], handle.publicKeyHex);
      expect(request.queryParameters['pageSize'], 100);
      expect(request.queryParameters.containsKey('status'), isFalse);

      _expectSignatureValid(
        handle: handle,
        signatureHex: request.queryParameters['signature'] as String,
        action: bullpayActionInvoiceList,
        nymOrEmpty: '',
        payloadFields: buildInvoiceListPayloadFields(page: 1, pageSize: 100),
        timestampSecs: timestamp,
      );
    });
  });

  group('T-INV-CLIENT status is unsigned', () {
    test('GETs /api/v1/invoices/:id/status with no signature', () async {
      final stub = _stubDio([_statusView()]);
      final client = BullnymHttpClient.withDio(stub.dio);

      await client.getInvoiceStatus(invoiceId: 'inv-1');

      final request = stub.captured.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/v1/invoices/inv-1/status');
      expect(request.queryParameters.containsKey('signature'), isFalse);
      expect(request.queryParameters.containsKey('npub'), isFalse);
    });
  });
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
