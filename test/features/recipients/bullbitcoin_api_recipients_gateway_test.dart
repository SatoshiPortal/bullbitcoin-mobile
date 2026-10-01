import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/sepa_payment_option.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/gateways/bullbitcoin_api_recipients_gateway.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Map<String, dynamic> _sepaRecipientJson({
  required String recipientId,
  bool isOwner = true,
  bool isCorporate = false,
  String? virtualPayeeStatus,
  List<String>? paymentProcessors,
}) => {
  'recipientId': recipientId,
  'userId': 'user-1',
  'userNbr': 42,
  'isArchived': false,
  'createdAt': '2026-09-03T12:00:00.000Z',
  'updatedAt': '2026-09-03T12:01:00.000Z',
  'recipientTypeFiat': 'SEPA_EUR',
  'iban': 'DE89370400440532013000',
  'isOwner': isOwner,
  'isCorporate': isCorporate,
  if (isCorporate) 'corporateName': 'Example GmbH',
  if (!isCorporate) 'firstname': 'Sat',
  if (!isCorporate) 'lastname': 'Oshi',
  'virtualPayeeStatus': ?virtualPayeeStatus,
  'paymentProcessors': ?paymentProcessors,
};

void main() {
  late _MockDio dio;
  late BullbitcoinApiRecipientsGateway gateway;

  setUp(() {
    dio = _MockDio();
    gateway = BullbitcoinApiRecipientsGateway(authenticatedApiClient: dio);
  });

  void stubRecipients(List<Map<String, dynamic>> elements) {
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
        data: {
          'result': {'elements': elements, 'totalElements': elements.length},
        },
      ),
    );
  }

  test('keeps same-ID regular and confidential processor choices', () async {
    stubRecipients([
      _sepaRecipientJson(
        recipientId: 'recipient-1',
        virtualPayeeStatus: 'ACTIVE',
        paymentProcessors: const ['REGULAR_SEPA', 'CONFIDENTIAL_SEPA'],
      ),
    ]);

    final result = await gateway.listRecipients(
      isTestnet: false,
      recipientTypes: const [
        RecipientType.sepaEur,
        RecipientType.confidentialSepaEur,
      ],
    );

    expect(result.recipients, hasLength(2));
    expect(
      result.recipients.map((recipient) => recipient.recipientId).toSet(),
      {'recipient-1'},
    );
    expect(result.recipients.map((recipient) => recipient.type).toSet(), {
      RecipientType.sepaEur,
      RecipientType.confidentialSepaEur,
    });
  });

  test(
    'does not offer regular SEPA for a confidential-only recipient',
    () async {
      stubRecipients([
        _sepaRecipientJson(
          recipientId: 'recipient-1',
          virtualPayeeStatus: 'ACTIVE',
          paymentProcessors: const ['CONFIDENTIAL_SEPA'],
        ),
      ]);

      final result = await gateway.listRecipients(
        isTestnet: false,
        recipientTypes: const [
          RecipientType.sepaEur,
          RecipientType.confidentialSepaEur,
        ],
      );

      expect(result.recipients, hasLength(1));
      expect(result.recipients.single.type, RecipientType.confidentialSepaEur);
      final details = result.recipients.single.details as SepaEurDetails;
      expect(details.paymentOptions, const {SepaPaymentOption.confidential});
      expect(details.supportsRegularSepa, isFalse);
    },
  );

  test('adds an activation choice for eligible plain SEPA', () async {
    stubRecipients([
      _sepaRecipientJson(
        recipientId: 'recipient-1',
        paymentProcessors: const ['REGULAR_SEPA'],
      ),
    ]);

    final result = await gateway.listRecipients(
      isTestnet: false,
      recipientTypes: const [RecipientType.confidentialSepaEur],
    );

    expect(result.recipients, hasLength(1));
    expect(result.recipients.single.type, RecipientType.confidentialSepaEur);
    expect(result.recipients.single.recipientId, 'recipient-1');
  });

  test('falls back to regular SEPA when processors are missing', () async {
    stubRecipients([
      _sepaRecipientJson(
        recipientId: 'recipient-1',
        virtualPayeeStatus: 'ACTIVE',
      ),
    ]);

    final result = await gateway.listRecipients(
      isTestnet: false,
      recipientTypes: const [RecipientType.sepaEur],
    );

    expect(result.recipients, hasLength(1));
    expect(result.recipients.single.type, RecipientType.sepaEur);
  });

  test('does not add activation choices for ineligible SEPA', () async {
    stubRecipients([
      _sepaRecipientJson(recipientId: 'not-owner', isOwner: false),
      _sepaRecipientJson(recipientId: 'corporate', isCorporate: true),
    ]);

    final result = await gateway.listRecipients(
      isTestnet: false,
      recipientTypes: const [RecipientType.confidentialSepaEur],
    );

    expect(result.recipients, isEmpty);
  });
}
