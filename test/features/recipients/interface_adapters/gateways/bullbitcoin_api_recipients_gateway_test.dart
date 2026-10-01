import 'package:bb_mobile/features/recipients/interface_adapters/gateways/bullbitcoin_api_recipients_gateway.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late BullbitcoinApiRecipientsGateway gateway;

  setUp(() {
    dio = _MockDio();
    gateway = BullbitcoinApiRecipientsGateway(authenticatedApiClient: dio);
    when(
      () => dio.post(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: '/ak/api-recipients'),
        statusCode: 200,
        data: {'result': <String, dynamic>{}},
      ),
    );
  });

  test('updates an Interac recipient with supplied security details', () async {
    await gateway.updateInteracSecurityDetails(
      recipientId: 'recipient-1',
      email: 'person@example.com',
      securityQuestion: 'Favourite city?',
      securityAnswer: 'Montreal',
      isTestnet: false,
    );

    final request =
        verify(
              () => dio.post(
                '/ak/api-recipients',
                data: captureAny(named: 'data'),
                options: any(named: 'options'),
              ),
            ).captured.single
            as Map<String, dynamic>;

    expect(request, {
      'jsonrpc': '2.0',
      'id': '0',
      'method': 'updateMyRecipient',
      'params': {
        'element': {
          'recipientId': 'recipient-1',
          'recipientType': 'OUT_INTERAC_EMAIL',
          'email': 'person@example.com',
          'securityQuestion': 'Favourite city?',
          'securityAnswer': 'Montreal',
        },
      },
    });
  });

  test(
    'sends null security details when the saved default is cleared',
    () async {
      await gateway.updateInteracSecurityDetails(
        recipientId: 'recipient-1',
        email: 'person@example.com',
        securityQuestion: null,
        securityAnswer: null,
        isTestnet: false,
      );

      final request =
          verify(
                () => dio.post(
                  '/ak/api-recipients',
                  data: captureAny(named: 'data'),
                  options: any(named: 'options'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      final element =
          (request['params'] as Map<String, dynamic>)['element']
              as Map<String, dynamic>;

      expect(element['securityQuestion'], isNull);
      expect(element['securityAnswer'], isNull);
    },
  );
}
