import 'dart:convert';

import 'package:bbx_api/bbx_api.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'fake_http.dart';
import 'result_helpers.dart';

void main() {
  late FakeHttp http;

  Bbx answer(Object? body, {int status = 200}) {
    http = FakeHttp(status: status, body: body);
    return bbx(http);
  }

  RequestOptions request(String path) {
    final request = http.requests.single;
    expect(request.path, path);
    expect(request.method, 'POST');
    expect(request.headers['x-api-version'], isNull);
    return request;
  }

  /// The JSON-RPC request, as the JSON text on the wire.
  String sent(String path) => jsonEncode(request(path).data);

  group('getCopPaymentLink', () {
    test('sends the bank, amount and callback and reads the link', () async {
      final api = answer({'result': 'https://pay.example/cop'}).orders;

      final link = valueOf(
        await api.getCopPaymentLink(
          bankCode: 'BC01',
          amount: 50000,
          callbackUrl: 'https://app.example',
        ),
      );

      expect(
        sent('/ak/api-orders'),
        '{"jsonrpc":"2.0","id":"0","method":"getCopPaymentLink","params":'
        '{"paymentProcessorCode":null,"bankCode":"BC01","amount":50000,'
        '"callbackUrl":"https://app.example"}}',
      );
      expect(link, 'https://pay.example/cop');
    });

    for (final result in <Object?>[null, 42, <String, Object?>{}]) {
      test('a result of $result is a format error', () async {
        final api = answer({'result': result}).orders;

        expect(
          await failedCall(
            api.getCopPaymentLink(
              bankCode: 'BC01',
              amount: 1,
              callbackUrl: 'https://app.example',
            ),
          ),
          isA<BbxResponseFormatFailure>(),
        );
      });
    }

    test('a JSON-RPC error keeps its ERR_ code', () async {
      final api = answer({
        'error': {
          'code': -32000,
          'message': 'Internal error',
          'data': {
            'apiError': {'code': 'ERR_ORD_COP400'},
          },
        },
      }).orders;

      expect(
        await failedCall(
          api.getCopPaymentLink(
            bankCode: 'BC01',
            amount: 1,
            callbackUrl: 'https://app.example',
          ),
        ),
        isA<BbxRpcFailure>().having(
          (f) => f.apiCode,
          'apiCode',
          'ERR_ORD_COP400',
        ),
      );
    });
  });

  group('getUserPaymentProcessorCode', () {
    test('sends the payment processor and reads both objects', () async {
      final api = answer({
        'result': {
          'element': {'code': 'ABC123', 'userNbr': 7},
          'ppExtraData': {'BENEFICIARY NAME': 'Bull Bitcoin'},
        },
      }).recipients;

      final details = valueOf(
        await api.getUserPaymentProcessorCode('IN_CAD_EMAIL_TRANSFER_APL'),
      );

      expect(
        sent('/ak/api-recipients'),
        '{"jsonrpc":"2.0","id":"0","method":"getUserPaymentProcessorCode",'
        '"params":{"paymentProcessorCode":"IN_CAD_EMAIL_TRANSFER_APL",'
        '"bankCode":null,"amount":null,"callbackUrl":null}}',
      );
      expect(details.code, 'ABC123');
      expect(details.userNbr, '7');
      expect(details.beneficiaryName, 'Bull Bitcoin');
    });

    test('missing objects are empty', () async {
      final api = answer({'result': <String, Object?>{}}).recipients;

      final details = valueOf(
        await api.getUserPaymentProcessorCode('IN_CAD_LOADHUB'),
      );

      expect(details.isEmpty, isTrue);
      expect(details.code, isNull);
      expect(details.beneficiaryName, isNull);
    });

    for (final result in <Object?>[
      null,
      'details',
      {'element': 'ABC123'},
      {'ppExtraData': <Object?>[]},
    ]) {
      test('a result of $result is a format error', () async {
        final api = answer({'result': result}).recipients;

        expect(
          await failedCall(api.getUserPaymentProcessorCode('IN_CAD_LOADHUB')),
          isA<BbxResponseFormatFailure>(),
        );
      });
    }
  });

  group('listInstitutionCodes', () {
    const accountType = {
      'code': 'SAVINGS',
      'name': 'Savings',
      'minAddressLength': 8,
      'maxAddressLength': 16.0,
    };

    test('sends the country and reads the institutions', () async {
      final api = answer({
        'result': {
          'elements': [
            {
              'code': 'BC01',
              'name': 'Bancolombia',
              'accountTypes': [accountType],
            },
            {'code': 'DV01', 'name': 'Davivienda', 'accounTypes': <Object?>[]},
            {'code': 'NO01', 'name': 'No types'},
            {'code': 3, 'name': 'Bad code', 'accountTypes': <Object?>[]},
            {
              'code': 'BT01',
              'name': 'Bad type',
              'accountTypes': [
                {'code': 'X', 'name': 'X', 'minAddressLength': 1},
              ],
            },
            'not an object',
          ],
        },
      }).recipients;

      final list = valueOf(await api.listInstitutionCodes(countryCode: 'co'));

      expect(
        sent('/ak/api-recipients'),
        '{"jsonrpc":"2.0","id":"0","method":"listInstitutionCodes",'
        '"params":{"countryCode":"co"}}',
      );
      expect(list.institutions.map((i) => i.code), ['BC01', 'DV01']);
      final type = list.institutions.first.accountTypes.single;
      expect(type.code, 'SAVINGS');
      expect(type.name, 'Savings');
      expect(type.minAddressLength, 8);
      expect(type.maxAddressLength, 16);
      expect(list.institutions[1].accountTypes, isEmpty);
      expect(list.skippedElements, 4);
    });

    test('a present but null accountTypes is not read from the typo', () async {
      final api = answer({
        'result': {
          'elements': [
            {
              'code': 'BC01',
              'name': 'Bancolombia',
              'accountTypes': null,
              'accounTypes': <Object?>[],
            },
          ],
        },
      }).recipients;

      final list = valueOf(await api.listInstitutionCodes(countryCode: 'co'));

      expect(list.institutions, isEmpty);
      expect(list.skippedElements, 1);
    });

    test('a missing element list is empty', () async {
      final api = answer({'result': <String, Object?>{}}).recipients;

      final list = valueOf(await api.listInstitutionCodes(countryCode: 'co'));

      expect(list.institutions, isEmpty);
      expect(list.skippedElements, 0);
    });

    for (final result in <Object?>[
      null,
      <Object?>[],
      {'elements': 'BC01'},
    ]) {
      test('a result of $result is a format error', () async {
        final api = answer({'result': result}).recipients;

        expect(
          await failedCall(api.listInstitutionCodes(countryCode: 'co')),
          isA<BbxResponseFormatFailure>(),
        );
      });
    }
  });
}
