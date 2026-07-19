import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/data/bullnym_http_client.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_get_paid_transaction_actions.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockHttpAdapter extends Mock implements HttpClientAdapter {}

class _Captured {
  final List<RequestOptions> requests = [];
}

({Dio dio, _Captured captured}) _stubDio(Object? response, {int status = 200}) {
  final captured = _Captured();
  final adapter = _MockHttpAdapter();
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://bullnym.test',
      validateStatus: (value) => value != null && value < 600,
    ),
  )..httpClientAdapter = adapter;
  when(() => adapter.fetch(any(), any(), any())).thenAnswer((invocation) async {
    captured.requests.add(
      invocation.positionalArguments.first as RequestOptions,
    );
    return ResponseBody.fromString(
      jsonEncode(response),
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );
  });
  return (dio: dio, captured: captured);
}

List<int> _oracleMessage({
  required String npub,
  required String cursor,
  required int limit,
  required int timestamp,
}) {
  final bytes = <int>[];
  void field(String value) {
    bytes
      ..addAll(utf8.encode(value))
      ..add(0);
  }

  field('bullpay-la-v2');
  field('get-paid-transaction-list');
  field(npub);
  field('');
  field(cursor);
  field(limit.toString());
  bytes.addAll(utf8.encode(timestamp.toString()));
  return bytes;
}

Map<String, dynamic> _transaction({
  required String transactionId,
  required String source,
  required String? invoiceId,
  String rail = 'lightning',
  String settlementState = 'settled',
  Object? amountSat = 1000,
  Object? receivedAtUnix = 1710000000,
  Object? late = false,
  Object? comment,
}) {
  return {
    'transaction_id': transactionId,
    'source': source,
    'invoice_id': invoiceId,
    'amount_sat': amountSat,
    'received_at_unix': receivedAtUnix,
    'rail': rail,
    'settlement_state': settlementState,
    'late': late,
    'comment': ?comment,
  };
}

const _npub =
    '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
const _laId = '10000000-0000-4000-8000-000000000001';
const _invoiceEventId = '20000000-0000-4000-8000-000000000002';
const _pageEventId = '30000000-0000-4000-8000-000000000003';
const _posEventId = '40000000-0000-4000-8000-000000000004';
const _invoiceId = '50000000-0000-4000-8000-000000000005';

T _unwrap<T>(Result<T, BullnymFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw TestFailure('Expected Ok, got $failure'),
};

BullnymFailure _unwrapFailure<T>(Result<T, BullnymFailure> result) =>
    switch (result) {
      Ok() => throw TestFailure('Expected Err, got Ok'),
      Err(:final failure) => failure,
    };

void main() {
  const timestamp = 1711111111;
  setUpAll(() => registerFallbackValue(RequestOptions(path: '')));

  test(
    'signs the exact identity-wide cursor payload and parses all sources',
    () async {
      const cursor = 'opaque-cursor';
      final response = {
        'transactions': [
          _transaction(
            transactionId: _laId,
            source: 'lightning_address',
            invoiceId: null,
            comment: 'private payer note',
          ),
          _transaction(
            transactionId: _invoiceEventId,
            source: 'invoice',
            invoiceId: _invoiceId,
            rail: 'bitcoin',
            settlementState: 'problem',
            late: true,
          ),
          _transaction(
            transactionId: _pageEventId,
            source: 'payment_page',
            invoiceId: _invoiceId,
            rail: 'liquid',
            settlementState: 'pending',
          ),
          _transaction(
            transactionId: _posEventId,
            source: 'point_of_sale',
            invoiceId: _invoiceId,
          ),
        ],
        'next_cursor': null,
        'future_field': true,
      };
      final stub = _stubDio(response);
      String? signedHash;
      final signer = BullnymAuthSigner(
        npubHex: _npub,
        signHashHex: (value) {
          signedHash = value;
          return 'ab' * 64;
        },
      );
      final client = BullnymHttpClient.withDio(
        stub.dio,
        nowSecs: () => timestamp,
      );

      final page = _unwrap(
        await client.listGetPaidTransactions(
          signer: signer,
          cursor: cursor,
          limit: 4,
        ),
      );

      expect(bullpayActionGetPaidTransactionList, 'get-paid-transaction-list');
      expect(
        buildGetPaidTransactionListPayloadFields(cursor: cursor, limit: 4),
        [cursor, '4'],
      );
      expect(
        signedHash,
        sha256
            .convert(
              _oracleMessage(
                npub: _npub,
                cursor: cursor,
                limit: 4,
                timestamp: timestamp,
              ),
            )
            .toString(),
      );
      final request = stub.captured.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/v1/get-paid/transactions');
      expect(request.queryParameters, {
        'npub': _npub,
        'timestamp': timestamp,
        'signature': 'ab' * 64,
        'cursor': cursor,
        'limit': 4,
      });
      expect(
        page.transactions.map((item) => item.source).toList(),
        BullnymGetPaidTransactionSource.values,
      );
      expect(page.transactions.first.comment, 'private payer note');
      expect(page.transactions.first.toString(), isNot(contains('private')));
      expect(
        () => page.transactions.add(page.transactions.first),
        throwsUnsupportedError,
      );
      expect(page.nextCursor, isNull);
    },
  );

  test('rejects invalid pagination before network access', () async {
    final stub = _stubDio({'transactions': [], 'next_cursor': null});
    final client = BullnymHttpClient.withDio(stub.dio);
    final signer = BullnymAuthSigner(
      npubHex: _npub,
      signHashHex: (_) => 'ab' * 64,
    );

    for (final input in [
      (cursor: '', limit: 0),
      (cursor: '', limit: 101),
      (cursor: 'x' * 257, limit: 20),
      (cursor: 'bad\u0000cursor', limit: 20),
    ]) {
      final failure = _unwrapFailure(
        await client.listGetPaidTransactions(
          signer: signer,
          cursor: input.cursor,
          limit: input.limit,
        ),
      );
      expect(failure.kind, BullnymFailureKind.invalidInput);
    }
    expect(stub.captured.requests, isEmpty);
  });

  test('fails closed on malformed pages and unknown values', () async {
    final valid = _transaction(
      transactionId: _laId,
      source: 'lightning_address',
      invoiceId: null,
    );
    final cases = <Map<String, dynamic>>[
      {'transactions': 'not-a-list', 'next_cursor': null},
      {
        'transactions': [
          {...valid, 'source': 'future_source'},
        ],
        'next_cursor': null,
      },
      {
        'transactions': [
          {...valid, 'rail': 'future_rail'},
        ],
        'next_cursor': null,
      },
      {
        'transactions': [
          {...valid, 'settlement_state': 'future_state'},
        ],
        'next_cursor': null,
      },
      {
        'transactions': [
          {...valid, 'transaction_id': 'A0000000-0000-4000-8000-000000000001'},
        ],
        'next_cursor': null,
      },
      {
        'transactions': [
          {...valid, 'invoice_id': _invoiceId},
        ],
        'next_cursor': null,
      },
      {
        'transactions': [
          _transaction(
            transactionId: _invoiceEventId,
            source: 'invoice',
            invoiceId: null,
          ),
        ],
        'next_cursor': null,
      },
      {
        'transactions': [valid, valid],
        'next_cursor': null,
      },
      {
        'transactions': [
          {...valid, 'amount_sat': 0},
        ],
        'next_cursor': null,
      },
      {
        'transactions': [
          {...valid, 'received_at_unix': 0},
        ],
        'next_cursor': null,
      },
      {
        'transactions': [
          {
            ...valid,
            'received_at_unix': bullnymGetPaidTransactionMaxReceivedAtUnix + 1,
          },
        ],
        'next_cursor': null,
      },
      {
        'transactions': [
          {...valid, 'comment': 'x' * 513},
        ],
        'next_cursor': null,
      },
      {'transactions': [], 'next_cursor': 'has-more'},
      {
        'transactions': [valid],
        'next_cursor': '',
      },
      {
        'transactions': [valid],
        'next_cursor': 'bad\u0000cursor',
      },
      {
        'transactions': [valid],
        'next_cursor': 'same-cursor',
      },
    ];

    for (final response in cases) {
      final stub = _stubDio(response);
      final client = BullnymHttpClient.withDio(stub.dio);
      final signer = BullnymAuthSigner(
        npubHex: _npub,
        signHashHex: (_) => 'ab' * 64,
      );
      final failure = _unwrapFailure(
        await client.listGetPaidTransactions(
          signer: signer,
          cursor: 'same-cursor',
          limit: 20,
        ),
      );
      expect(
        failure.kind,
        BullnymFailureKind.invalidServerResponse,
        reason: response.toString(),
      );
    }
  });

  test('rejects a response larger than the signed limit', () async {
    final stub = _stubDio({
      'transactions': [
        _transaction(
          transactionId: _laId,
          source: 'lightning_address',
          invoiceId: null,
        ),
        _transaction(
          transactionId: _invoiceEventId,
          source: 'invoice',
          invoiceId: _invoiceId,
        ),
      ],
      'next_cursor': null,
    });
    final client = BullnymHttpClient.withDio(stub.dio);
    final signer = BullnymAuthSigner(
      npubHex: _npub,
      signHashHex: (_) => 'ab' * 64,
    );
    final failure = _unwrapFailure(
      await client.listGetPaidTransactions(
        signer: signer,
        cursor: '',
        limit: 1,
      ),
    );
    expect(failure.kind, BullnymFailureKind.invalidServerResponse);
  });
}
