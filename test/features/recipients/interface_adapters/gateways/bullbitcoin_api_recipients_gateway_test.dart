import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_details_dto.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/cad_biller.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/bullbitcoin_api_recipients_gateway.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

/// Shaped like a real refusal from this API: the JSON-RPC error object quotes
/// the payload it rejected, so it holds the user's banking details as well as
/// a server stack trace. Nothing here may reach the returned failure.
const _iban = 'DE89370400440532013000';
const _errorBody = {
  'error': {
    'code': -32602,
    'message': 'invalid iban $_iban',
    'data': {
      'stack': 'at RecipientService.create (/srv/api/recipients.js:214)',
    },
  },
};

Response<dynamic> _response(dynamic data, {int status = 200}) => Response(
  requestOptions: RequestOptions(path: '/ak/api-recipients'),
  statusCode: status,
  data: data,
);

RecipientDetails _details() => const RecipientDetailsDto(
  recipientType: RecipientType.sinpeMovilCrc,
  phoneNumber: '8888-8888',
).toDomain();

void main() {
  late _MockDio dio;
  late BullbitcoinApiRecipientsGateway gateway;

  setUp(() {
    dio = _MockDio();
    gateway = BullbitcoinApiRecipientsGateway(authenticatedApiClient: dio);
  });

  void stub(dynamic answer) {
    final call = when(
      () => dio.post<dynamic>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    );
    if (answer is Response) {
      call.thenAnswer((_) async => answer);
    } else {
      call.thenThrow(answer as Object);
    }
  }

  group('a JSON-RPC error is never carried into the failure', () {
    test('listRecipients', () async {
      stub(_response(_errorBody));

      final result = await gateway.listRecipients(isTestnet: true);

      switch (result) {
        case Ok():
          fail('a JSON-RPC error must not be reported as a recipient list');
        case Err(:final failure):
          expect(failure, isA<RecipientsLoadFailure>());
          // The refusal is logged, not carried: the payload quotes an IBAN.
          expect(failure.logMessage, isNull);
      }
    });

    test('saveRecipient', () async {
      stub(_response(_errorBody));

      final result = await gateway.saveRecipient(_details(), isTestnet: true);

      switch (result) {
        case Ok():
          fail('a JSON-RPC error must not be reported as a saved recipient');
        case Err(:final failure):
          expect(failure, isA<RecipientsSaveFailure>());
          expect(failure.logMessage, isNull);
      }
    });

    test('checkSinpe', () async {
      stub(_response(_errorBody));

      final result = await gateway.checkSinpe(
        phoneNumber: '+50688887777',
        isTestnet: true,
      );

      expect(result, isA<Err<String, RecipientsFailure>>());
      expect(
        (result as Err<String, RecipientsFailure>).failure,
        isA<RecipientsSinpeLookupFailure>(),
      );
    });

    test('listCadBillers', () async {
      stub(_response(_errorBody));

      final result = await gateway.listCadBillers(
        searchTerm: 'hydro',
        isTestnet: true,
      );

      expect(
        (result as Err<List<CadBiller>, RecipientsFailure>).failure,
        isA<RecipientsCadBillerSearchFailure>(),
      );
    });
  });

  test('a non-200 is a typed failure, not a thrown exception', () async {
    stub(_response(<String, dynamic>{}, status: 503));

    final result = await gateway.listRecipients(isTestnet: true);

    expect(result, isA<Err<dynamic, RecipientsFailure>>());
  });

  group('connectivity is told apart from an API refusal', () {
    test('a timeout maps to the network failure, which is the only one with '
        'advice the user can act on', () async {
      stub(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final result = await gateway.listRecipients(isTestnet: true);

      switch (result) {
        case Ok():
          fail('a timeout must not be reported as a recipient list');
        case Err(:final failure):
          expect(failure, isA<RecipientsNetworkFailure>());
      }
    });

    test('a bad response maps to the operation failure, not network', () async {
      stub(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.badResponse,
          message: 'invalid iban $_iban',
        ),
      );

      final result = await gateway.listRecipients(isTestnet: true);

      switch (result) {
        case Ok():
          fail('a bad response must not be reported as a recipient list');
        case Err(:final failure):
          expect(failure, isA<RecipientsLoadFailure>());
          expect(failure, isNot(isA<RecipientsNetworkFailure>()));
          // The Dio message quotes the request body — bank details.
          expect(failure.logMessage, isNull);
      }
    });
  });

  group('a malformed response degrades instead of throwing', () {
    test('a missing result is a typed failure', () async {
      stub(_response(<String, dynamic>{'result': null}));

      final result = await gateway.listRecipients(isTestnet: true);

      expect(
        (result as Err<dynamic, RecipientsFailure>).failure,
        isA<RecipientsLoadFailure>(),
      );
    });

    test('an unparseable element is skipped, not fatal: the API can return '
        'recipient types this build does not know yet', () async {
      stub(
        _response(<String, dynamic>{
          'result': {
            'totalElements': 2,
            'elements': [
              {'not': 'a recipient'},
              {'also not': 'a recipient'},
            ],
          },
        }),
      );

      final result = await gateway.listRecipients(isTestnet: true);

      switch (result) {
        case Ok(:final value):
          expect(value.recipients, isEmpty);
          // The total still reflects the server's count, so paging is not
          // silently corrupted by rows this build could not read.
          expect(value.totalRecipients, 2);
        case Err():
          fail('unparseable rows must not fail the whole list');
      }
    });
  });
}
