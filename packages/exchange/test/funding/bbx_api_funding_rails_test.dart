import 'package:exchange/exchange.dart';
import 'package:exchange/funding.dart';
import 'package:exchange/steps.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../bbx_api_test_http.dart';

const _session = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 0,
  sessionId: 'session',
);

/// The consent gate is the only maker of [ConsentGiven].
final _consent =
    (consentGateStart(alreadyGiven: true).state as ConsentGateGiven).given;

/// Every field any rail reads, split between `element` and `ppExtraData` as
/// the server does, with numeric values.
const _everyField = {
  'result': {
    'element': {'code': 'ABC123'},
    'ppExtraData': {
      'BENEFICIARY NAME': 'Bull Bitcoin',
      'BENEFICIARY EMAIL': 'pay@example.com',
      'BANK ACCOUNT DETAILS': 'details',
      'IBAN': 'DE89370400440532013000',
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

Map<String, dynamic> _rpcError(String apiCode) => {
  'error': {
    'code': -32000,
    'message': 'Internal error',
    'data': {
      'apiError': {'code': apiCode, 'en': 'refused'},
    },
  },
};

Map<String, Object?> _sent(FakeBbxHttp http) =>
    http.requests.single.data as Map<String, Object?>;

ProcessorCodeRequest _request(ProcessorCodeFundingRail rail) =>
    ProcessorCodeRequest(rail, userNumber: 4242, consent: _consent);

void main() {
  group('instructions', () {
    for (final rail in FundingRails.all.whereType<ProcessorCodeFundingRail>()) {
      test('${rail.name} sends its code and shows only its fields', () async {
        final http = FakeBbxHttp(body: _everyField);

        final read = await testExchange(http).funding
            .instructions(_session, _request(rail));

        expect(_sent(http)['method'], 'getUserPaymentProcessorCode');
        expect(
          (_sent(http)['params'] as Map)['paymentProcessorCode'],
          rail.paymentProcessorCode,
        );
        final instructions =
            ((read as ReadGot<FundingAnswer>).value as FundingInstructionsGot)
                .instructions;
        switch (instructions) {
          case FundingInstructionRows(:final rows):
            expect([for (final row in rows) row.field], rail.fields);
          case FundingInstructionQr(:final payload):
            expect(rail, const CanadaPostFundingRail());
            expect(payload, 'ABC123');
          case FundingInstructionLink():
            fail('a processor-code rail never answers a link');
        }
      });
    }

    test('the e-Transfer answer is the account user number', () async {
      final read = await testExchange(FakeBbxHttp(body: _everyField)).funding
          .instructions(_session, _request(const EmailETransferFundingRail()));

      expect(
        read,
        const ReadGot<FundingAnswer>(
          FundingInstructionsGot(
            FundingInstructionRows([
              InstructionRow(InstructionField.beneficiaryName, 'Bull Bitcoin'),
              InstructionRow(
                InstructionField.beneficiaryEmail,
                'pay@example.com',
              ),
              InstructionRow(InstructionField.secretQuestion, 'ABC123'),
              InstructionRow(InstructionField.secretAnswer, '4242'),
            ]),
          ),
        ),
      );
    });

    test('a missing field the rail shows is malformed (FUND-1)', () async {
      final read = await testExchange(
        FakeBbxHttp(
          body: {
            'result': {
              'element': {'code': 'ABC123'},
            },
          },
        ),
      ).funding.instructions(_session, _request(const SpeiFundingRail()));

      expect(read, isA<ReadMalformed<FundingAnswer>>());
    });

    test('a field the rail never shows is not required (03 §12.4)', () async {
      final answer = {
        'result': {
          'element': {'code': 'ABC123'},
          'ppExtraData': {
            for (final entry
                in (_everyField['result']!['ppExtraData']! as Map).entries)
              if (entry.key != 'IBAN' && entry.key != 'ACCOUNT NUMBER')
                entry.key: entry.value,
          },
        },
      };

      final read = await testExchange(FakeBbxHttp(body: answer)).funding
          .instructions(_session, _request(const BankWireFundingRail()));

      expect(read, isA<ReadGot<FundingAnswer>>());
    });

    for (final (apiCode, refusal) in [
      ('ERR_ORD_PO404', FundingRefusal.paymentOptionUnavailable),
      ('ERR_RCP_PO404', FundingRefusal.optionNotPermitted),
      ('ERR_RCP_POSINPE404', FundingRefusal.sinpeNotRegistered),
      ('ERR_ORD_KYC400', FundingRefusal.kycIncomplete),
      ('ERR_ORD_COP400', FundingRefusal.copRequestInvalid),
      ('ERR_ORD_CSRCP400', FundingRefusal.sepaVirtualPaymentInactive),
      ('ERR_RCP_400', FundingRefusal.requestInvalid),
    ]) {
      test('$apiCode is the refusal ${refusal.name}', () async {
        final read = await testExchange(FakeBbxHttp(body: _rpcError(apiCode)))
            .funding
            .instructions(_session, _request(const SinpeMovilFundingRail()));

        expect(read, ReadGot<FundingAnswer>(FundingRefused(refusal)));
      });
    }

    test('an unknown refusal code is not a refusal', () async {
      final read = await testExchange(
        FakeBbxHttp(body: _rpcError('ERR_SOMETHING_NEW')),
      ).funding.instructions(_session, _request(const SinpeMovilFundingRail()));

      expect(read, isA<ReadUnreachable<FundingAnswer>>());
    });

    test('a timeout is unreachable over the network', () async {
      final read = await testExchange(
        FakeBbxHttp(error: DioExceptionType.receiveTimeout),
      ).funding.instructions(_session, _request(const SinpeMovilFundingRail()));

      expect(
        read,
        isA<ReadUnreachable<FundingAnswer>>().having(
          (read) => read.isNetwork,
          'isNetwork',
          isTrue,
        ),
      );
    });

    test('a 401 rejects the session', () async {
      final read = await testExchange(
        FakeBbxHttp(status: 401, body: {'error': 'unauthorized'}),
      ).funding.instructions(_session, _request(const SinpeMovilFundingRail()));

      expect(read, isA<ReadSessionRejected<FundingAnswer>>());
    });

    test(
      'COP sends the bank, amount and callback, and answers its link',
      () async {
        final http = FakeBbxHttp(body: {'result': 'https://pay.example/cop'});

        final read = await testExchange(http).funding.instructions(
          _session,
          CopPaymentRequest(
            institution: FundingInstitution.create(code: 'BC01', name: 'Bank'),
            amount: CopAmount.parse('50000')!,
            consent: _consent,
          ),
        );

        expect(_sent(http)['method'], 'getCopPaymentLink');
        expect(_sent(http)['params'], {
          'paymentProcessorCode': null,
          'bankCode': 'BC01',
          'amount': 50000,
          'callbackUrl': 'https://app.bullbitcoin.com',
        });
        expect(
          read,
          ReadGot<FundingAnswer>(
            FundingInstructionsGot(
              FundingInstructionLink(Uri.parse('https://pay.example/cop')),
            ),
          ),
        );
      },
    );

    test('a COP link that is not a web page is malformed', () async {
      final read =
          await testExchange(
            FakeBbxHttp(body: {'result': 'javascript:alert(1)'}),
          ).funding.instructions(
            _session,
            CopPaymentRequest(
              institution: FundingInstitution.create(
                code: 'BC01',
                name: 'Bank',
              ),
              amount: CopAmount.parse('1')!,
              consent: _consent,
            ),
          );

      expect(read, isA<ReadMalformed<FundingAnswer>>());
    });
  });

  group('institutions', () {
    test('sends the lowercase country code and skips bad elements', () async {
      final http = FakeBbxHttp(
        body: {
          'result': {
            'elements': [
              {'code': 'BC01', 'name': 'Bank one'},
              {'code': ' ', 'name': 'No code'},
            ],
          },
        },
      );

      final read = await testExchange(http).funding
          .institutions(_session, Jurisdiction.colombia);

      expect((_sent(http)['params'] as Map)['countryCode'], 'co');
      expect([for (final bank in (read as ReadGot).value) bank.code], ['BC01']);
    });

    test('a failed list is unreachable, never an empty list', () async {
      final read = await testExchange(
        FakeBbxHttp(error: DioExceptionType.connectionError),
      ).funding.institutions(_session, Jurisdiction.colombia);

      expect(read, isA<ReadUnreachable<List<FundingInstitution>>>());
    });
  });

  group('consent', () {
    test('success true is done', () async {
      expect(
        await testExchange(
          FakeBbxHttp(
            body: {
              'result': {'success': true},
            },
          ),
        ).funding.consent(_session),
        isA<WriteDone<void>>(),
      );
    });

    test('any other answer is unknown, so the gate re-reads', () async {
      expect(
        await testExchange(
          FakeBbxHttp(
            body: {
              'result': {'success': false},
            },
          ),
        ).funding.consent(_session),
        isA<WriteOutcomeUnknown<void>>(),
      );
    });

    test('a lost connection is unknown, never a refusal', () async {
      expect(
        await testExchange(FakeBbxHttp(error: DioExceptionType.connectionError))
            .funding
            .consent(_session),
        isA<WriteOutcomeUnknown<void>>(),
      );
    });
  });

  test('a call for another environment is not sent', () async {
    final http = FakeBbxHttp(body: _everyField);

    final read = await testExchange(
      http,
      isTestnet: true,
    ).funding.instructions(_session, _request(const SpeiFundingRail()));

    expect(http.requests, isEmpty);
    expect(read, isA<ReadUnreachable<FundingAnswer>>());
  });
}
