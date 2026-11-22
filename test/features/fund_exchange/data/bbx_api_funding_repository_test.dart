import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/fund_exchange/data/bbx_api_funding_repository.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_institution.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/domain/repositories/funding_repository.dart';
import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../exchange/data/bbx_api_test_http.dart';
import '../result_helpers.dart';
import 'bbx_api_funding_repository_legacy.dart';

const _iban = 'DE89370400440532013000';

const _methods = <FundingMethod>[
  EmailETransfer(),
  BankTransferWire(),
  OnlineBillPayment(),
  CanadaPost(),
  InstantSepa(),
  RegularSepa(),
  SpeiTransfer(),
  Sinpe(),
  CrIbanCrc(),
  CrIbanUsd(),
  ArsBankTransfer(),
  CopBankTransfer(bankCode: 'BC01', amountCop: 50000),
];

/// Funding instructions with every field any method reads, split between
/// `element` and `ppExtraData` like the server does, with a numeric value.
const _details = {
  'result': {
    'element': {'code': 'ABC123', 'userNbr': 7, 'IBAN': 'overridden'},
    'ppExtraData': {
      'BENEFICIARY NAME': 'Bull Bitcoin',
      'BENEFICIARY EMAIL': 'pay@example.com',
      'BANK ACCOUNT DETAILS': 'details',
      'IBAN': _iban,
      'SWIFT': 'SWIFTXX',
      'INSTITUTION NUMBER': 1,
      'TRANSIT NUMBER': '12345',
      'ACCOUNT NUMBER': '1234567',
      'ROUTING NUMBER': '021000021',
      'BENEFICIARY ADDRESS': '1 Main St',
      'BANK ADDRESS': '2 Bank St',
      'BANK NAME': 'Bank',
      'BILLER NAME': 'Bull Bitcoin Biller',
      'BIC': 'BICXX',
      'BANK ACCOUNT COUNTRY': 'FR',
      'BANK COUNTRY': 'DE',
      'CLABE': '002010077777777771',
      'CÉDULA JURÍDICA': '3-101-123456',
      'CVU': '0000003100010000000001',
      'NUM TELEFONO': 88888888,
    },
  },
};

Map<String, dynamic> _rpcError(Object? code) => {
  'error': {
    'code': -32000,
    'message': 'Internal error',
    'data': {
      'apiError': {'code': code, 'en': 'Recipient $_iban is not active'},
    },
  },
};

/// Everything the app reads from funding details.
Map<String, Object?> _canonical(FundingDetails d) => switch (d) {
  ETransferFundingDetails() => {
    'type': 'etransfer',
    'secretQuestion': d.secretQuestion,
    'beneficiaryName': d.beneficiaryName,
    'beneficiaryEmail': d.beneficiaryEmail,
  },
  CanadaPostFundingDetails() => {'type': 'canadaPost', 'code': d.code},
  BillPaymentFundingDetails() => {
    'type': 'bill',
    'code': d.code,
    'billerName': d.billerName,
  },
  InstantSepaFundingDetails() => {
    'type': 'instantSepa',
    'code': d.code,
    'iban': d.iban,
    'bic': d.bic,
    'beneficiaryName': d.beneficiaryName,
    'beneficiaryAddress': d.beneficiaryAddress,
    'bankAccountCountry': d.bankAccountCountry,
  },
  RegularSepaFundingDetails() => {
    'type': 'regularSepa',
    'code': d.code,
    'iban': d.iban,
    'bic': d.bic,
    'beneficiaryName': d.beneficiaryName,
    'beneficiaryAddress': d.beneficiaryAddress,
    'bankCountry': d.bankCountry,
  },
  WireFundingDetails() => {
    'type': 'wire',
    'code': d.code,
    'beneficiaryName': d.beneficiaryName,
    'bankAccountDetails': d.bankAccountDetails,
    'iban': d.iban,
    'swift': d.swift,
    'institutionNumber': d.institutionNumber,
    'transitNumber': d.transitNumber,
    'accountNumber': d.accountNumber,
    'routingNumber': d.routingNumber,
    'beneficiaryAddress': d.beneficiaryAddress,
    'bankAddress': d.bankAddress,
    'bankName': d.bankName,
  },
  SpeiFundingDetails() => {
    'type': 'spei',
    'code': d.code,
    'bankName': d.bankName,
    'beneficiaryName': d.beneficiaryName,
    'clabe': d.clabe,
  },
  SinpeFundingDetails() => {
    'type': 'sinpe',
    'number': d.number,
    'beneficiaryName': d.beneficiaryName,
  },
  CrIbanCrcFundingDetails() => {
    'type': 'crIbanCrc',
    'iban': d.iban,
    'code': d.code,
    'beneficiaryName': d.beneficiaryName,
    'cedulaJuridica': d.cedulaJuridica,
  },
  CrIbanUsdFundingDetails() => {
    'type': 'crIbanUsd',
    'iban': d.iban,
    'code': d.code,
    'beneficiaryName': d.beneficiaryName,
    'cedulaJuridica': d.cedulaJuridica,
  },
  ArsBankTransferFundingDetails() => {
    'type': 'ars',
    'beneficiaryName': d.beneficiaryName,
    'cvu': d.cvu,
  },
  CopBankTransferFundingDetails() => {
    'type': 'cop',
    'paymentLink': d.paymentLink,
  },
};

FundingRepository _new(HttpClientAdapter http, {ReadExchangeApiKey? key}) =>
    BbxApiFundingRepository(
      api: bbxForTesting(
        endpoint: testBbxEndpoint,
        adapter: http,
        readActiveApiKey: bbxCredentialRead(key),
      ),
    );

/// The path and JSON text of each request.
List<(String, String)> _sent(FakeBbxHttp http) => [
  for (final r in http.requests) (r.path, jsonEncode(r.data)),
];

typedef _Operation = Future<Result<Object?, FundExchangeFailure>> Function(
  FundingRepository,
);

final _operations = <String, _Operation>{
  'getFundingDetails': (r) =>
      r.getFundingDetails(fundingMethod: const RegularSepa()),
  'getFundingDetails (COP)': (r) => r.getFundingDetails(
    fundingMethod: const CopBankTransfer(bankCode: 'BC01', amountCop: 1),
  ),
  'listInstitutions': (r) =>
      r.listInstitutions(jurisdiction: FundingJurisdiction.colombia),
  'registerResponsibilityConsent': (r) => r.registerResponsibilityConsent(),
};

/// Runs [call] on the repository; returns what the old repository sent and
/// gave for the same answer, recorded before it was removed (see
/// [_legacyOutcome]), and what the repository sends and gives.
Future<
  (
    (List<Object?>, Object?),
    (List<(String, String)>, Result<Object?, FundExchangeFailure>),
  )
>
_both(
  String id,
  _Operation call, {
  Object? body,
  int status = 200,
  DioExceptionType? error,
  ReadExchangeApiKey? key,
}) async {
  final http = FakeBbxHttp(body: body, status: status, error: error);
  final result = await call(_new(http, key: key));
  final old = oldRepository[id];
  if (old is! (List<Object?>, Object?)) {
    fail('Expected a legacy funding fixture for $id');
  }
  return (old, (_sent(http), result));
}

List<Object?> _legacyResult(Object? result) {
  if (result is! List<Object?>) {
    fail('Expected a recorded funding result');
  }
  return result;
}

void main() {
  group('getFundingDetails matches the old repository, as recorded', () {
    for (final method in _methods) {
      test(method.runtimeType.toString(), () async {
        final isCop = method is CopBankTransfer;
        final ((oldSent, oldResult), (sent, result)) = await _both(
          'details ${method.runtimeType}',
          (r) => r.getFundingDetails(fundingMethod: method),
          body: isCop ? {'result': 'https://pay.example/cop'} : _details,
        );

        expect(sent, oldSent);
        expect(sent.single.$1, isCop ? '/ak/api-orders' : '/ak/api-recipients');
        expect(_legacyOutcome(result), oldResult);
      });
    }

    test('sends the COP bank, amount and app callback', () async {
      final http = FakeBbxHttp(body: {'result': 'https://pay.example/cop'});

      final result = await _new(http).getFundingDetails(
        fundingMethod: const CopBankTransfer(
          bankCode: 'BC01',
          amountCop: 50000,
        ),
      );

      expect(
        _sent(http).single.$2,
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":'
        '{"paymentProcessorCode":null,"bankCode":"BC01","amount":50000,'
        '"callbackUrl":"${ApiServiceConstants.bbAppUrl}"}}',
      );
      expect(
        (valueOf(result) as CopBankTransferFundingDetails).paymentLink,
        'https://pay.example/cop',
      );
    });

    test('reads the phone number aliases and the extra data', () async {
      for (final alias in [
        'NUM TELEFONO',
        'NUM_TELEFONO',
        'PHONE NUMBER',
        'phoneNumber',
      ]) {
        final http = FakeBbxHttp(
          body: {
            'result': {
              'element': {alias: 88888888},
              'ppExtraData': {'BENEFICIARY NAME': 'Bull Bitcoin'},
            },
          },
        );

        final details = valueOf(
          await _new(http).getFundingDetails(fundingMethod: const Sinpe()),
        ) as SinpeFundingDetails;

        expect(details.number, '88888888', reason: alias);
        expect(details.beneficiaryName, 'Bull Bitcoin');
      }
    });
  });

  group('listInstitutions matches the old repository, as recorded', () {
    for (final jurisdiction in FundingJurisdiction.values) {
      test('sends the lowercase country code of $jurisdiction', () async {
        final ((oldSent, _), (sent, _)) = await _both(
          'institutions $jurisdiction',
          (r) => r.listInstitutions(jurisdiction: jurisdiction),
          body: {
            'result': {'elements': <Object?>[]},
          },
        );

        expect(sent, oldSent);
        expect(
          sent.single.$2,
          '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes",'
          '"params":{"countryCode":"${jurisdiction.code.toLowerCase()}"}}',
        );
      });
    }

    test('keeps and skips the same elements', () async {
      const type = {
        'code': 'SAVINGS',
        'name': 'Savings',
        'minAddressLength': 8,
        'maxAddressLength': 16,
      };
      final ((_, oldResult), (_, result)) = await _both(
        'institutions kept and skipped',
        (r) => r.listInstitutions(jurisdiction: FundingJurisdiction.colombia),
        body: {
          'result': {
            'elements': [
              {
                'code': ' BC01 ',
                'name': 'Bancolombia',
                'accountTypes': [type],
              },
              {
                'code': 'DV01',
                'name': 'Davivienda',
                'accounTypes': [type],
              },
              {'code': '', 'name': 'Blank', 'accountTypes': <Object?>[]},
              {'code': 'NM01', 'name': '  ', 'accountTypes': <Object?>[]},
              {'code': 'NT01', 'name': 'No types'},
              {
                'code': 'BT01',
                'name': 'Bad type',
                'accountTypes': [
                  {'code': 'X'},
                ],
              },
              {'code': 1, 'name': 'Numeric', 'accountTypes': <Object?>[]},
              'not an object',
            ],
          },
        },
      );

      List<(String, String)> institutions(
        Result<Object?, FundExchangeFailure> r,
      ) {
        final value = valueOf(r);
        if (value is! List<FundingInstitution>) {
          fail('Expected a list of funding institutions');
        }
        return [for (final i in value) (i.code, i.name)];
      }

      expect(_legacyOutcome(result), oldResult);
      expect(institutions(result), [
        ('BC01', 'Bancolombia'),
        ('DV01', 'Davivienda'),
      ]);
    });

    for (final body in [
      {
        'result': {'elements': <Object?>[]},
      },
      {'result': <String, Object?>{}},
      {
        'result': {
          'elements': [
            {'code': '', 'name': '', 'accountTypes': <Object?>[]},
          ],
        },
      },
    ]) {
      test('$body is NoInstitutionsFailure', () async {
        final ((_, oldResult), (_, result)) = await _both(
          'no institutions $body',
          (r) => r.listInstitutions(jurisdiction: FundingJurisdiction.canada),
          body: body,
        );

        expect(failureOf(result), isA<FundExchangeNoInstitutionsFailure>());
        expect(_legacyResult(oldResult)[0], FundExchangeNoInstitutionsFailure);
      });
    }
  });

  group(
    'registerResponsibilityConsent matches the old repository, as recorded',
    () {
      for (final result in <Object?>[
        true,
        null,
        {'success': true},
        {'success': false},
        'ok',
      ]) {
        test('a result of $result is a consent', () async {
          final ((oldSent, oldResult), (sent, newResult)) = await _both(
            'consent $result',
            (r) => r.registerResponsibilityConsent(),
            body: {'result': result},
          );

          expect(sent, oldSent);
          expect(sent.single, (
            '/ak/api-users',
            '{"jsonrpc":"2.0","id":"0","method":'
                '"registerResponsibilityConsent","params":{}}',
          ));
          expect(newResult, isA<Ok<void, FundExchangeFailure>>());
          expect(oldResult, ['ok', null]);
        });
      }
    },
  );

  group('failures match the old repository', () {
    final answers =
        <String, ({Object? body, int status, DioExceptionType? error})>{
          for (final code in [
            'ERR_ORD_PO404',
            'ERR_RCP_PO404',
            'ERR_RCP_POSINPE404',
            'ERR_ORD_KYC400',
            'ERR_ORD_COP400',
            'ERR_ORD_CSRCP400',
            'ERR_RCP_400',
            'ERR_SOMETHING_NEW',
          ])
            code: (body: _rpcError(code), status: 200, error: null),
          'a numeric API code': (
            body: _rpcError(400),
            status: 200,
            error: null,
          ),
          'a JSON-RPC error without data': (
            body: {
              'error': {'message': 'refused'},
            },
            status: 200,
            error: null,
          ),
          for (final error in <Object>['refused', 42, true, <Object?>[]])
            'a non-object error $error': (
              body: {'error': error},
              status: 200,
              error: null,
            ),
          'status 503': (body: {}, status: 503, error: null),
          'status 204': (body: {}, status: 204, error: null),
          'a body that is not an object': (
            body: 'oops',
            status: 200,
            error: null,
          ),
          'a result that is not an object': (
            body: {'result': 42},
            status: 200,
            error: null,
          ),
          'a missing result': (
            body: {'result': null},
            status: 200,
            error: null,
          ),
          for (final type in DioExceptionType.values)
            if (type != DioExceptionType.unknown &&
                type != DioExceptionType.cancel)
              'a $type': (body: null, status: 200, error: type),
        };

    for (final MapEntry(key: name, value: call) in _operations.entries) {
      for (final MapEntry(key: answer, value: a) in answers.entries) {
        test('$name: $answer', () async {
          final ((_, oldResult), (_, result)) = await _both(
            '$name: $answer',
            call,
            body: a.body,
            status: a.status,
            error: a.error,
          );

          final old = _legacyResult(oldResult);
          switch (result) {
            case Ok():
              expect(old[0], 'ok');
            case Err(:final failure):
              expect(failure.runtimeType, old[0]);
          }
        });
      }

      test(
        '$name: a transformTimeout keeps its legacy failure message',
        () async {
          final http = FakeBbxHttp(error: DioExceptionType.transformTimeout);

          final failure = failureOf(await call(_new(http)));

          expect(http.requests, hasLength(1));
          expect(
            failure,
            name == 'registerResponsibilityConsent'
                ? isA<FundExchangeConsentRegistrationFailure>()
                : isA<FundExchangeUnexpectedFailure>(),
          );
          expect(failure.logMessage, 'Transport failure: transformTimeout');
        },
      );

      test('$name: a missing API key is NotAuthenticated', () async {
        final ((oldSent, oldResult), (sent, result)) = await _both(
          '$name: no key',
          call,
          key: () async => const Ok(null),
        );

        expect(sent, isEmpty);
        expect(oldSent, isEmpty);
        expect(failureOf(result), isA<FundExchangeNotAuthenticatedFailure>());
        expect(
          _legacyResult(oldResult)[0],
          FundExchangeNotAuthenticatedFailure,
        );
      });

      test('$name: an unreadable API key is unexpected', () async {
        final ((_, oldResult), (_, result)) = await _both(
          '$name: unreadable key',
          call,
          key: () async => const Err(ExchangeApiKeyReadFailure()),
        );

        expect(failureOf(result), isA<FundExchangeUnexpectedFailure>());
        expect(failureOf(result).logMessage, 'Exchange credential unavailable');
        expect(_legacyResult(oldResult)[1], failureOf(result).logMessage);
      });

      test('$name: a programmer error is rethrown', () async {
        await expectLater(
          call(_new(_ThrowingAdapter(StateError('defect')))),
          throwsStateError,
        );
      });

      test('$name: an unknown adapter exception omits foreign text', () async {
        final repository = _new(
          _ThrowingAdapter(Exception('fixture-sensitive-funding-cause')),
        );

        final failure = failureOf(await call(repository));

        expect(failure.logMessage, startsWith('DioException('));
        expect(
          failure.logMessage,
          isNot(contains('fixture-sensitive-funding-cause')),
        );

        expect(
          failure,
          name == 'registerResponsibilityConsent'
              ? isA<FundExchangeConsentRegistrationFailure>()
              : isA<FundExchangeUnexpectedFailure>(),
        );
      });
    }

    test('failure diagnostics keep codes and omit server text', () async {
      Future<String?> logMessage(FakeBbxHttp http) async => failureOf(
        await _new(http).getFundingDetails(fundingMethod: const RegularSepa()),
      ).logMessage;

      expect(await logMessage(FakeBbxHttp(status: 503)), 'HTTP 503');
      expect(
        await logMessage(FakeBbxHttp(error: DioExceptionType.connectionError)),
        'Unreachable: connectionError',
      );
      expect(
        await logMessage(FakeBbxHttp(error: DioExceptionType.badCertificate)),
        'Transport failure: badCertificate',
      );
      // Only the JSON-RPC codes survive: the server's sentence can name the
      // user's IBAN.
      final rpcMessage = await logMessage(
        FakeBbxHttp(body: _rpcError('ERR_ORD_KYC400')),
      );
      expect(
        rpcMessage,
        'BbxRpcFailure(code: -32000, apiCode: ERR_ORD_KYC400)',
      );
    });

    test('a malformed element is unexpected, not a crash', () async {
      final result = await _new(
        FakeBbxHttp(
          body: {
            'result': {'element': 'ABC123'},
          },
        ),
      ).getFundingDetails(fundingMethod: const CanadaPost());

      expect(failureOf(result), isA<FundExchangeUnexpectedFailure>());
    });
  });
}

class _ThrowingAdapter implements HttpClientAdapter {
  final Object _error;

  _ThrowingAdapter(this._error);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw _error;
}

/// A result in the form the old repository's answers were recorded in.
Object? _legacyOutcome(Result<Object?, FundExchangeFailure> r) => switch (r) {
  Ok(:final value) => [
    'ok',
    switch (value) {
      final FundingDetails d => _canonical(d),
      final List<FundingInstitution> l => [for (final i in l) (i.code, i.name)],
      _ => value,
    },
  ],
  Err(:final failure) => [failure.runtimeType, failure.logMessage],
};
