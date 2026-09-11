import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/features/fund_exchange/adapters/funding_gateway/bullbitcoin_api_funding_gateway.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/domain/primitives/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_method.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

/// The IBAN the API echoes back in `messageData` for ERR_ORD_CSRCP400.
const _iban = 'DE89370400440532013000';

/// The backend's English sentence — the string that used to be rendered
/// verbatim on the funding screens (#1895).
const _backendSentence =
    'Recipient $_iban has no virtual payment option configured';

/// Builds a Dio whose adapter always answers with [body] and [statusCode],
/// so the gateway can be exercised without a network.
Dio _dioReturning(dynamic body, {int statusCode = 200}) {
  final dio = Dio();
  dio.httpClientAdapter = _StubAdapter(body: body, statusCode: statusCode);
  return dio;
}

Map<String, dynamic> _jsonRpcError({
  required String code,
  Map<String, String>? messageData,
}) => {
  'jsonrpc': '2.0',
  'id': '0',
  'error': {
    'code': -32000,
    'message': 'Internal error',
    'data': {
      'apiError': {
        'code': code,
        'en': _backendSentence,
        'messageData': ?messageData,
      },
    },
  },
};

void main() {
  group('BullBitcoinApiFundingGateway.getFundingDetails', () {
    test('maps each known API code to its own failure variant', () async {
      const expected = <String, Type>{
        'ERR_ORD_PO404': FundExchangePaymentOptionUnavailableFailure,
        'ERR_RCP_PO404': FundExchangeOptionNotPermittedFailure,
        'ERR_RCP_POSINPE404': FundExchangeSinpeNotRegisteredFailure,
        'ERR_ORD_KYC400': FundExchangeKycIncompleteFailure,
        'ERR_ORD_COP400': FundExchangeCopRequestInvalidFailure,
        'ERR_ORD_CSRCP400': FundExchangeSepaVirtualPaymentInactiveFailure,
        'ERR_RCP_400': FundExchangeRequestInvalidFailure,
      };

      for (final entry in expected.entries) {
        final gateway = BullBitcoinApiFundingGateway(
          authenticatedApiClient: _dioReturning(_jsonRpcError(code: entry.key)),
        );

        final result = await gateway.getFundingDetails(
          fundingMethod: RegularSepa(),
        );

        expect(result, isA<Err<dynamic, FundExchangeFailure>>());
        expect(
          (result as Err).failure.runtimeType,
          entry.value,
          reason: '${entry.key} mapped to the wrong variant',
        );
      }
    });

    test('an unknown API code falls back to the catch-all', () async {
      final gateway = BullBitcoinApiFundingGateway(
        authenticatedApiClient: _dioReturning(
          _jsonRpcError(code: 'ERR_SOMETHING_NEW'),
        ),
      );

      final result = await gateway.getFundingDetails(
        fundingMethod: RegularSepa(),
      );

      expect((result as Err).failure, isA<FundExchangeUnexpectedFailure>());
    });

    test('keeps the backend sentence and IBAN in logMessage only', () async {
      final gateway = BullBitcoinApiFundingGateway(
        authenticatedApiClient: _dioReturning(
          _jsonRpcError(code: 'ERR_ORD_CSRCP400', messageData: {'iban': _iban}),
        ),
      );

      final result = await gateway.getFundingDetails(
        fundingMethod: RegularSepa(),
      );
      final failure = (result as Err).failure as FundExchangeFailure;

      // The reason survives for diagnosis...
      expect(failure.logMessage, contains(_backendSentence));
      // ...and the variant carries no other field that could reach the UI.
      expect(failure, isA<FundExchangeSepaVirtualPaymentInactiveFailure>());
      expect(
        failure.toString(),
        isNot(contains('messageData')),
        reason: 'the raw messageData payload must not be retained',
      );
    });

    test('a non-200 status never leaks the body', () async {
      final gateway = BullBitcoinApiFundingGateway(
        authenticatedApiClient: _dioReturning({
          'oops': _backendSentence,
        }, statusCode: 503),
      );

      final result = await gateway.getFundingDetails(
        fundingMethod: RegularSepa(),
      );
      final failure = (result as Err).failure as FundExchangeFailure;

      expect(failure, isA<FundExchangeUnexpectedFailure>());
      expect(failure.logMessage, isNot(contains(_backendSentence)));
    });

    test(
      'a thrown transport error becomes the catch-all, not an exception',
      () async {
        final dio = Dio();
        dio.httpClientAdapter = _ThrowingAdapter();
        final gateway = BullBitcoinApiFundingGateway(
          authenticatedApiClient: dio,
        );

        final result = await gateway.getFundingDetails(
          fundingMethod: RegularSepa(),
        );
        final failure = (result as Err).failure as FundExchangeFailure;

        // Like every converted feature, the catch-all keeps the stringified
        // exception for diagnosis. That is safe because it lands in
        // `logMessage`, which the l10n extension never reads — asserted in
        // fund_exchange_failure_l10n_test.dart.
        expect(failure, isA<FundExchangeUnexpectedFailure>());
        expect(failure.logMessage, contains(_backendSentence));
      },
    );
  });

  group('BullBitcoinApiFundingGateway.listInstitutions', () {
    test('an empty element list becomes NoInstitutionsFailure', () async {
      final gateway = BullBitcoinApiFundingGateway(
        authenticatedApiClient: _dioReturning({
          'jsonrpc': '2.0',
          'id': '0',
          'result': {'elements': <dynamic>[]},
        }),
      );

      final result = await gateway.listInstitutions(
        jurisdiction: FundingJurisdiction.colombia,
      );

      expect((result as Err).failure, isA<FundExchangeNoInstitutionsFailure>());
    });

    test('unparseable elements are skipped, not surfaced raw', () async {
      final gateway = BullBitcoinApiFundingGateway(
        authenticatedApiClient: _dioReturning({
          'jsonrpc': '2.0',
          'id': '0',
          'result': {
            'elements': [
              {'code': '', 'name': '', 'accountTypes': <dynamic>[]},
              {
                'code': 'BC01',
                'name': 'Bancolombia',
                'accountTypes': <dynamic>[],
              },
            ],
          },
        }),
      );

      final result = await gateway.listInstitutions(
        jurisdiction: FundingJurisdiction.colombia,
      );

      expect(result, isA<Ok<dynamic, FundExchangeFailure>>());
      final institutions = (result as Ok).value;
      expect(institutions, hasLength(1));
      expect(institutions.single.code, 'BC01');
    });
  });

  group('BullBitcoinApiFundingGateway.registerResponsibilityConsent', () {
    test('an API error becomes ConsentRegistrationFailure', () async {
      final gateway = BullBitcoinApiFundingGateway(
        authenticatedApiClient: _dioReturning({
          'jsonrpc': '2.0',
          'id': 1,
          'error': {'message': _backendSentence},
        }),
      );

      final result = await gateway.registerResponsibilityConsent();
      final failure = (result as Err).failure as FundExchangeFailure;

      expect(failure, isA<FundExchangeConsentRegistrationFailure>());
    });

    test('a 200 with no error is Ok', () async {
      final gateway = BullBitcoinApiFundingGateway(
        authenticatedApiClient: _dioReturning({
          'jsonrpc': '2.0',
          'id': 1,
          'result': true,
        }),
      );

      expect(
        await gateway.registerResponsibilityConsent(),
        isA<Ok<void, FundExchangeFailure>>(),
      );
    });
  });
}

class _StubAdapter implements HttpClientAdapter {
  final dynamic body;
  final int statusCode;

  _StubAdapter({required this.body, required this.statusCode});

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _ThrowingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw StateError(_backendSentence);
}
