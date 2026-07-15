import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/nostr/nostr_keychain_handle.dart';
import 'package:bb_mobile/core/utils/result.dart';
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
    'presentation_status': 'available',
    'pricing_mode': 'sat',
    'settlement_status': 'none',
    'amount_sat': 25000,
    'remaining_amount_sat': paid ? 0 : 25000,
    'fiat_amount_minor': null,
    'fiat_currency': null,
    'memo': null,
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

Map<String, dynamic> _fallbackView({
  String recoveryStatus = 'refund_due',
  String? refundAddress,
  String? refundTxid,
}) {
  return {
    'items': [
      {
        'invoice_id': 'inv-1',
        'nym': 'merchant-nym',
        'recovery_status': recoveryStatus,
        'user_lock_amount_sat': 105000,
        'server_lock_amount_sat': 100000,
        'lockup_address': 'bc1plockup',
        'refund_address': refundAddress,
        'refund_txid': refundTxid,
        'swap_created_at_unix': 1767000000,
        'swap_updated_at_unix': 1767003600,
        'invoice': {
          'status': 'expired',
          'amount_sat': 100000,
          'fiat_amount_minor': 5000,
          'fiat_currency': 'CAD',
          'public_description': 'Order 123',
          'invoice_number': 'INV-42',
          'created_at_unix': 1766990000,
        },
        'future_server_field': true,
      },
    ],
    'count': 1,
    'has_more': false,
  };
}

BullnymCreateInvoiceFields _lnLiquidFields() {
  return BullnymCreateInvoiceFields(
    amountSat: 25000,
    clientRequestId: '00000000-0000-4000-8000-000000000001',
    presentationEnvelope: 'A' * 5500,
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
      'pins the unlinked 12-field layout: all fields present, empties as "", '
      'booleans true/false, nym slot empty',
      () {
        // Fiat-denominated, LN+Liquid, no BTC — so amount_sat is empty, fiat
        // fields present, bitcoin_address empty. Hand-derived oracle.
        final fields = BullnymCreateInvoiceFields(
          fiatAmountMinor: 1050,
          fiatCurrency: 'CAD',
          clientRequestId: '00000000-0000-4000-8000-000000000001',
          presentationEnvelope: 'A' * 5500,
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
          payloadFields: [
            '', // amount_sat empty (fiat-denominated)
            '1050', // fiat_amount_minor
            'CAD', // fiat_currency
            '00000000-0000-4000-8000-000000000001',
            'A' * 5500,
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
          _unwrap(
            buildBullpaySchnorrMessage(
              action: bullpayActionInvoiceCreate,
              npubHex: 'npub',
              nymOrEmpty: '',
              payloadFields: buildInvoiceCreatePayloadFields(fields),
              timestampSecs: timestamp,
            ),
          ),
          oracle,
        );
        expect(buildInvoiceCreatePayloadFields(fields).length, 12);
      },
    );

    test('sat-denominated omitted-optionals still emit all 12 fields', () {
      final fields = BullnymCreateInvoiceFields(
        amountSat: 25000,
        clientRequestId: '00000000-0000-4000-8000-000000000001',
        presentationEnvelope: 'A' * 5500,
        acceptBtc: true,
        acceptLn: false,
        acceptLiquid: false,
        bitcoinAddress: 'bc1qtest',
        expiresAtUnix: 1710086400,
      );
      expect(buildInvoiceCreatePayloadFields(fields), [
        '25000',
        '', // fiat_amount_minor
        '', // fiat_currency
        '00000000-0000-4000-8000-000000000001',
        'A' * 5500,
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
        _unwrap(
          buildBullpaySchnorrMessage(
            action: bullpayActionInvoiceCreate,
            npubHex: 'npub',
            nymOrEmpty: 'alice',
            payloadFields: buildInvoiceCreatePayloadFields(_lnLiquidFields()),
            timestampSecs: timestamp,
          ),
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
        _unwrap(
          buildBullpaySchnorrMessage(
            action: bullpayActionInvoiceCancel,
            npubHex: 'npub',
            nymOrEmpty: '',
            payloadFields: buildInvoiceCancelPayloadFields('inv-1'),
            timestampSecs: timestamp,
          ),
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
        _unwrap(
          buildBullpaySchnorrMessage(
            action: bullpayActionInvoiceList,
            npubHex: 'npub',
            nymOrEmpty: '',
            payloadFields: buildInvoiceListPayloadFields(
              page: 1,
              pageSize: 100,
            ),
            timestampSecs: timestamp,
          ),
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

  group('T-INV-SIGN fallback supervision byte layout', () {
    test('pins zero payload fields and an empty nym slot', () {
      expect(bullpayActionInvoiceRecoveryList, 'invoice-recovery-list');
      expect(buildInvoiceRecoveryListPayloadFields(), isEmpty);
      final oracle = _oracleMessageBytes(
        action: 'invoice-recovery-list',
        npubHex: 'npub',
        nymOrEmpty: '',
        payloadFields: const [],
        timestampSecs: timestamp,
      );
      expect(
        _unwrap(
          buildBullpaySchnorrMessage(
            action: bullpayActionInvoiceRecoveryList,
            npubHex: 'npub',
            nymOrEmpty: '',
            payloadFields: buildInvoiceRecoveryListPayloadFields(),
            timestampSecs: timestamp,
          ),
        ),
        oracle,
      );
    });
  });

  group('T-INV-DTO parse round-trips', () {
    test(
      'status shape parses and ignores unknown keys (tolerant reader)',
      () async {
        final client = BullnymHttpClient.withDio(
          _stubDio([_statusView(status: 'paid')]).dio,
        );
        final status = _unwrap(
          await client.getInvoiceStatus(invoiceId: 'inv-1'),
        );
        expect(status.status, 'paid');
        expect(status.liquidAddress, 'lq1qtest');
        expect(status.acceptLiquid, isTrue);
      },
    );

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
      final client = BullnymHttpClient.withDio(
        stub.dio,
        nowSecs: () => timestamp,
      );
      final result = _unwrap(
        await client.listInvoices(signer: signer, page: 1, pageSize: 100),
      );
      expect(result.pageSize, 100);
      expect(result.hasMore, isFalse);
      expect(result.invoices.first.nymOwner, isNull);
      expect(result.invoices.first.paidAtUnix, isNull);
      expect(result.invoices.last.status, 'paid');
      expect(result.invoices.last.paidVia, 'liquid');
    });

    test(
      'fallback projection parses one swap per row and ignores additions',
      () async {
        final client = BullnymHttpClient.withDio(
          _stubDio([
            _fallbackView(
              recoveryStatus: 'refunded',
              refundAddress: 'bc1qfallback',
              refundTxid: 'ab' * 32,
            ),
          ]).dio,
          nowSecs: () => timestamp,
        );

        final result = _unwrap(
          await client.listFallbackSupervision(signer: signer),
        );

        expect(result.count, 1);
        expect(result.hasMore, isFalse);
        final item = result.items.single;
        expect(item.invoiceId, 'inv-1');
        expect(item.recoveryStatus, 'refunded');
        expect(item.userLockAmountSat, 105000);
        expect(item.serverLockAmountSat, 100000);
        expect(item.refundAddress, 'bc1qfallback');
        expect(item.refundTxid, 'ab' * 32);
        expect(item.invoice.invoiceNumber, 'INV-42');
      },
    );

    test(
      'fallback projection rejects inconsistent count and negative money',
      () async {
        final inconsistent = _fallbackView()..['count'] = 2;
        final negative = _fallbackView();
        (negative['items'] as List).single['user_lock_amount_sat'] = -1;
        for (final response in [inconsistent, negative]) {
          final client = BullnymHttpClient.withDio(
            _stubDio([response]).dio,
            nowSecs: () => timestamp,
          );
          final failure = _unwrapFailure(
            await client.listFallbackSupervision(signer: signer),
          );
          expect(failure.kind, BullnymFailureKind.invalidServerResponse);
        }
      },
    );
  });

  group('T-INV-CLIENT create', () {
    test(
      'POSTs the unlinked body and signs the exact 12-field layout',
      () async {
        final stub = _stubDio([
          {
            'invoice_id': 'inv-1',
            'invoice_url': 'https://bullpay.ca/invoice/inv-1',
          },
        ]);
        final client = BullnymHttpClient.withDio(
          stub.dio,
          nowSecs: () => timestamp,
        );

        final response = _unwrap(
          await client.createInvoice(signer: signer, fields: _lnLiquidFields()),
        );

        expect(response.invoiceId, 'inv-1');
        expect(response.invoiceUrl, 'https://bullpay.ca/invoice/inv-1');

        final request = stub.captured.requests.single;
        expect(request.method, 'POST');
        expect(request.path, '/api/v1/invoices');
        final body = request.data as Map<String, dynamic>;
        expect(body['npub'], handle.publicKeyHex);
        expect(body['client_request_id'], _lnLiquidFields().clientRequestId);
        expect(
          body['presentation_envelope'],
          _lnLiquidFields().presentationEnvelope,
        );
        expect(body['accept_ln'], true);
        expect(body['accept_liquid'], true);
        expect(body['accept_btc'], false);
        expect(body['liquid_address'], 'lq1qtest');
        expect(body['liquid_blinding_key_hex'], 'ab12cd');
        expect(body.containsKey('public_description'), isFalse);
        expect(body.containsKey('recipient_name'), isFalse);
        expect(body.containsKey('invoice_number'), isFalse);
        expect(body.containsKey('viewing_key'), isFalse);

        _expectSignatureValid(
          handle: handle,
          signatureHex: body['signature'] as String,
          action: bullpayActionInvoiceCreate,
          nymOrEmpty: '',
          payloadFields: buildInvoiceCreatePayloadFields(_lnLiquidFields()),
          timestampSecs: timestamp,
        );
      },
    );

    test('maps the InvalidAmount envelope to a typed rejection', () async {
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
      final failure = _unwrapFailure(
        await client.createInvoice(signer: signer, fields: _lnLiquidFields()),
      );
      expect(failure.code, 'InvalidAmount');
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

      final response = _unwrap(
        await client.cancelInvoice(signer: signer, invoiceId: 'inv-1'),
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
    test(
      'GETs /api/v1/invoices with signed query and empty-nym signature',
      () async {
        final stub = _stubDio([
          {'invoices': [], 'page': 1, 'pageSize': 100, 'has_more': false},
        ]);
        final client = BullnymHttpClient.withDio(
          stub.dio,
          nowSecs: () => timestamp,
        );

        _unwrap(
          await client.listInvoices(signer: signer, page: 1, pageSize: 100),
        );

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
      },
    );
  });

  group('T-INV-CLIENT fallback supervision is read-only', () {
    test('GETs the signed npub-wide endpoint with no payload fields', () async {
      final stub = _stubDio([
        {'items': [], 'count': 0, 'has_more': false},
      ]);
      final client = BullnymHttpClient.withDio(
        stub.dio,
        nowSecs: () => timestamp,
      );

      _unwrap(await client.listFallbackSupervision(signer: signer));

      final request = stub.captured.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/v1/invoices/recoverable');
      expect(request.data, isNull);
      expect(request.queryParameters.keys.toSet(), {
        'npub',
        'timestamp',
        'signature',
      });
      _expectSignatureValid(
        handle: handle,
        signatureHex: request.queryParameters['signature'] as String,
        action: bullpayActionInvoiceRecoveryList,
        nymOrEmpty: '',
        payloadFields: const [],
        timestampSecs: timestamp,
      );
    });
  });

  group('T-INV-CLIENT status is unsigned', () {
    test('GETs /api/v1/invoices/:id/status with no signature', () async {
      final stub = _stubDio([_statusView()]);
      final client = BullnymHttpClient.withDio(stub.dio);

      _unwrap(await client.getInvoiceStatus(invoiceId: 'inv-1'));

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

T _unwrap<T>(Result<T, BullnymFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError('Expected Ok, got $failure'),
};

BullnymFailure _unwrapFailure<T>(Result<T, BullnymFailure> result) =>
    switch (result) {
      Ok() => throw StateError('Expected Err, got Ok'),
      Err(:final failure) => failure,
    };
