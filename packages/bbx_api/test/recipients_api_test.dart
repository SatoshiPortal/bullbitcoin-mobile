import 'dart:convert';

import 'package:bbx_api/bbx_api.dart';
import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'fake_http.dart';
import 'result_helpers.dart';

const _fiatRecipient = {
  'recipientId': 'r-1',
  'userId': 'u-1',
  'userNbr': 7,
  'isArchived': false,
  'createdAt': '2026-11-20T10:00:00Z',
  'updatedAt': '2026-11-20T11:00:00Z',
  'recipientTypeFiat': 'SEPA_EUR',
  'label': 'Rent',
  'isOwner': true,
  'isDefault': false,
  'iban': 'DE89370400440532013000',
  'isCorporate': false,
  'firstname': 'Ada',
  'lastname': 'Lovelace',
  'virtualPayeeStatus': 'ACTIVE',
};

const _myRecipient = {
  'recipientId': 'r-2',
  'userId': 'u-1',
  'recipientType': 'OUT_LIGHTNING_ADDRESS',
  'lightningAddress': 'sat@example.com',
  'isOwner': true,
  'isDefault': true,
  'createdAt': '2026-11-20T10:00:00Z',
  'updatedAt': '2026-11-20T11:00:00Z',
};

void main() {
  late FakeHttp http;
  late RecipientsApi api;

  void answer(Object? body, {int status = 200}) {
    http = FakeHttp(status: status, body: body);
    api = bbx(http).recipients;
  }

  RequestOptions request() {
    final request = http.requests.single;
    expect(request.path, '/ak/api-recipients');
    expect(request.method, 'POST');
    return request;
  }

  /// The JSON-RPC request, as the JSON text on the wire.
  String sent() => jsonEncode(request().data);

  String? apiVersion() => request().headers['x-api-version'] as String?;

  group('listMyRecipients', () {
    test('sends the filters that are given and reads the elements', () async {
      answer({
        'result': {
          'elements': [_myRecipient],
        },
      });

      final recipients = valueOf(
        await api.listMyRecipients(
          recipientTypes: ['OUT_BITCOIN_ADDRESS', 'OUT_LIGHTNING_ADDRESS'],
          isDefault: true,
        ),
      );

      expect(
        sent(),
        '{"jsonrpc":"2.0","id":"0","method":"listMyRecipients","params":'
        '{"filters":{"recipientTypes":["OUT_BITCOIN_ADDRESS",'
        '"OUT_LIGHTNING_ADDRESS"],"isDefault":true}}}',
      );
      expect(apiVersion(), isNull);
      final recipient = recipients.single;
      expect(recipient.recipientId, 'r-2');
      expect(recipient.userId, 'u-1');
      expect(recipient.recipientType, 'OUT_LIGHTNING_ADDRESS');
      expect(recipient.address, isNull);
      expect(recipient.lightningAddress, 'sat@example.com');
      expect(recipient.isOwner, isTrue);
      expect(recipient.isDefault, isTrue);
      expect(recipient.createdAt, '2026-11-20T10:00:00Z');
    });

    test('sends empty filters when none is given', () async {
      answer({'result': <String, Object?>{}});

      expect(valueOf(await api.listMyRecipients()), isEmpty);
      expect(
        sent(),
        '{"jsonrpc":"2.0","id":"0","method":"listMyRecipients","params":'
        '{"filters":{}}}',
      );
    });

    test('an invalid element fails the whole list', () async {
      answer({
        'result': {
          'elements': [
            _myRecipient,
            {'recipientId': 42},
          ],
        },
      });

      expect(
        await failedCall(api.listMyRecipients()),
        isA<BbxResponseFormatFailure>(),
      );
    });
  });

  group('createMyRecipient', () {
    test('sends the old element and reads the created recipient', () async {
      answer({
        'result': {'element': _myRecipient},
      });

      final recipient = valueOf(
        await api.createMyRecipient(
          recipientType: 'OUT_LIGHTNING_ADDRESS',
          address: 'sat@example.com',
          isOwner: true,
          isDefault: true,
        ),
      );

      expect(
        sent(),
        '{"jsonrpc":"2.0","id":"0","method":"createMyRecipient","params":'
        '{"element":{"recipientType":"OUT_LIGHTNING_ADDRESS","isOwner":true,'
        '"isDefault":true,"address":"sat@example.com"}}}',
      );
      expect(apiVersion(), isNull);
      expect(recipient.recipientId, 'r-2');
    });

    test('a result without an element is a format error', () async {
      answer({'result': <String, Object?>{}});

      expect(
        await failedCall(
          api.createMyRecipient(
            recipientType: 'OUT_BITCOIN_ADDRESS',
            address: 'bc1q',
            isOwner: true,
            isDefault: true,
          ),
        ),
        isA<BbxResponseFormatFailure>(),
      );
    });
  });

  group('updateMyRecipient', () {
    test('sends every field that is given', () async {
      answer({
        'result': {'element': _myRecipient},
      });

      valueOf(
        await api.updateMyRecipient(
          recipientId: 'r-2',
          recipientType: 'OUT_BITCOIN_ADDRESS',
          address: 'bc1q',
          isDefault: false,
        ),
      );

      expect(
        sent(),
        '{"jsonrpc":"2.0","id":"0","method":"updateMyRecipient","params":'
        '{"element":{"recipientId":"r-2","recipientType":"OUT_BITCOIN_ADDRESS",'
        '"isOwner":true,"address":"bc1q","isDefault":false}}}',
      );
      expect(apiVersion(), isNull);
    });

    test('leaves out the fields that are not given', () async {
      answer({
        'result': {'element': _myRecipient},
      });

      valueOf(
        await api.updateMyRecipient(
          recipientId: 'r-2',
          recipientType: 'OUT_LIQUID_ADDRESS',
          isOwner: false,
        ),
      );

      expect(
        sent(),
        '{"jsonrpc":"2.0","id":"0","method":"updateMyRecipient","params":'
        '{"element":{"recipientId":"r-2","recipientType":"OUT_LIQUID_ADDRESS",'
        '"isOwner":false}}}',
      );
    });
  });

  group('createRecipientFiat', () {
    test(
      'sends the recipient with version 2 and reads the saved one',
      () async {
        answer({
          'result': {'element': _fiatRecipient},
        });

        final saved = valueOf(
          await api.createRecipientFiat(
            const NewSepaEurRecipient(
              iban: 'DE89370400440532013000',
              isCorporate: false,
              firstname: 'Ada',
              lastname: 'Lovelace',
              label: 'Rent',
              isOwner: true,
              isDefault: false,
            ),
          ),
        );

        expect(
          sent(),
          '{"jsonrpc":"2.0","id":"0","method":"createRecipientFiat","params":'
          '{"element":{"recipientTypeFiat":"SEPA_EUR","label":"Rent",'
          '"isOwner":true,"isDefault":false,"isArchived":false,'
          '"iban":"DE89370400440532013000","isCorporate":false,'
          '"firstname":"Ada","lastname":"Lovelace"}}}',
        );
        expect(apiVersion(), '2.0.0');
        expect(saved.recipientId, 'r-1');
        expect(saved.userId, 'u-1');
        expect(saved.userNbr, 7);
        expect(saved.isArchived, isFalse);
        expect(saved.createdAt, '2026-11-20T10:00:00Z');
        expect(saved.updatedAt, '2026-11-20T11:00:00Z');
        expect(saved.recipientTypeFiat, 'SEPA_EUR');
        expect(saved.label, 'Rent');
        expect(saved.isOwner, isTrue);
        expect(saved.isDefault, isFalse);
        expect(saved.iban, 'DE89370400440532013000');
        expect(saved.isCorporate, isFalse);
        expect(saved.firstname, 'Ada');
        expect(saved.lastname, 'Lovelace');
        expect(saved.corporateName, isNull);
        expect(saved.virtualPayeeStatus, 'ACTIVE');
      },
    );

    test('a saved recipient without its identity is a format error', () async {
      answer({
        'result': {
          'element': {..._fiatRecipient, 'userNbr': '7'},
        },
      });

      expect(
        await failedCall(
          api.createRecipientFiat(const NewSepaEurRecipient(iban: 'DE89')),
        ),
        isA<BbxResponseFormatFailure>().having(
          (f) => f.reason,
          'reason',
          'invalid userNbr',
        ),
      );
    });
  });

  group('NewFiatRecipient', () {
    final payloads = <NewFiatRecipient, String>{
      const NewInteracEmailCadRecipient(
        email: 'a@example.com',
        name: 'Ada',
        securityQuestion: 'Q',
        securityAnswer: 'A',
        label: 'L',
        isOwner: true,
        isDefault: false,
      ): '{"recipientTypeFiat":"INTERAC_EMAIL_CAD","label":"L",'
          '"isOwner":true,"isDefault":false,"isArchived":false,'
          '"email":"a@example.com","name":"Ada","securityQuestion":"Q",'
          '"securityAnswer":"A"}',
      const NewBillPaymentCadRecipient(
        payeeName: 'Hydro',
        payeeCode: '0001',
        payeeAccountNumber: '123',
        isDefault: true,
      ): '{"recipientTypeFiat":"BILL_PAYMENT_CAD","isDefault":true,'
          '"isArchived":false,"payeeName":"Hydro","payeeCode":"0001",'
          '"payeeAccountNumber":"123"}',
      const NewBankTransferCadRecipient(
        name: 'Ada',
        institutionNumber: '001',
        transitNumber: '12345',
        accountNumber: '1234567',
        defaultComment: 'rent',
      ): '{"recipientTypeFiat":"BANK_TRANSFER_CAD","isArchived":false,'
          '"name":"Ada","institutionNumber":"001","transitNumber":"12345",'
          '"accountNumber":"1234567","defaultComment":"rent"}',
      const NewSepaEurRecipient(
        iban: 'DE89',
        isCorporate: true,
        corporateName: 'ACME',
      ): '{"recipientTypeFiat":"SEPA_EUR","isArchived":false,"iban":"DE89",'
          '"isCorporate":true,"corporateName":"ACME"}',
      const NewSpeiClabeMxnRecipient(name: 'Ada', clabe: '002010077777777771'):
          '{"recipientTypeFiat":"SPEI_CLABE_MXN","isArchived":false,'
          '"name":"Ada","clabe":"002010077777777771"}',
      const NewSpeiSmsMxnRecipient(
        name: 'Ada',
        institutionCode: '40002',
        phone: '5512345678',
      ): '{"recipientTypeFiat":"SPEI_SMS_MXN","isArchived":false,'
          '"name":"Ada","institutionCode":"40002","phone":"5512345678"}',
      const NewSpeiCardMxnRecipient(
        name: 'Ada',
        institutionCode: '40002',
        debitcard: '4111111111111111',
      ): '{"recipientTypeFiat":"SPEI_CARD_MXN","isArchived":false,'
          '"name":"Ada","institutionCode":"40002",'
          '"debitcard":"4111111111111111"}',
      const NewSinpeIbanUsdRecipient(iban: 'CR05', ownerName: 'Ada'):
          '{"recipientTypeFiat":"SINPE_IBAN_USD","isArchived":false,'
          '"iban":"CR05","ownerName":"Ada"}',
      const NewSinpeIbanCrcRecipient(iban: 'CR05'):
          '{"recipientTypeFiat":"SINPE_IBAN_CRC","isArchived":false,'
          '"iban":"CR05"}',
      const NewSinpeMovilCrcRecipient(
        phoneNumber: '88888888',
        ownerName: 'Ada',
      ): '{"recipientTypeFiat":"SINPE_MOVIL_CRC","isArchived":false,'
          '"ownerName":"Ada","phoneNumber":"88888888"}',
      const NewBankTransferArsRecipient(
        name: 'Ada',
        claveUniform: '0000003100010000000001',
      ): '{"recipientTypeFiat":"BANK_TRANSFER_ARS","isArchived":false,'
          '"name":"Ada","claveUniform":"0000003100010000000001"}',
      const NewPseColombiaCopRecipient(
        name: 'Ada',
        bankCode: '1007',
        accountType: 'SAVINGS',
        bankAccount: '123',
        bankName: 'Bancolombia',
        documentId: '99',
        documentType: 'CC',
      ): '{"recipientTypeFiat":"PSE_COLOMBIA_COP","isArchived":false,'
          '"name":"Ada","bankCode":"1007","accountType":"SAVINGS",'
          '"bankAccount":"123","bankName":"Bancolombia","documentId":"99",'
          '"documentType":"CC"}',
      const NewNequiColombiaCopRecipient(
        name: 'Ada',
        bankAccount: '3001234567',
        documentId: '99',
        documentType: 'CC',
      ): '{"recipientTypeFiat":"NEQUI_COLOMBIA_COP","isArchived":false,'
          '"name":"Ada","bankAccount":"3001234567","documentId":"99",'
          '"documentType":"CC"}',
    };

    for (final MapEntry(key: recipient, value: json) in payloads.entries) {
      test('${recipient.recipientTypeFiat} is sent as its flat fields', () {
        expect(jsonEncode(newFiatRecipientJsonForTesting(recipient)), json);
      });
    }
  });

  group('updateInteracSecurityDetails', () {
    test('sends the details with version 2, nulls included', () async {
      answer({
        'result': {'element': _fiatRecipient},
      });

      valueOf(
        await api.updateInteracSecurityDetails(
          recipientId: 'r-1',
          email: 'a@example.com',
          securityQuestion: null,
          securityAnswer: null,
        ),
      );

      expect(
        sent(),
        '{"jsonrpc":"2.0","id":"0","method":"updateMyRecipient","params":'
        '{"element":{"recipientId":"r-1","recipientType":"OUT_INTERAC_EMAIL",'
        '"email":"a@example.com","securityQuestion":null,'
        '"securityAnswer":null}}}',
      );
      expect(apiVersion(), '2.0.0');
    });

    test('a JSON-RPC error is a failure', () async {
      answer({
        'error': {'code': -32602, 'message': 'bad answer'},
      });

      expect(
        await failedCall(
          api.updateInteracSecurityDetails(
            recipientId: 'r-1',
            email: 'a@example.com',
            securityQuestion: 'Q',
            securityAnswer: 'A',
          ),
        ),
        isA<BbxRpcFailure>(),
      );
    });
  });

  group('listRecipientsFiat', () {
    test('sends the page and the given filters with version 2', () async {
      answer({
        'result': {
          'elements': [_fiatRecipient],
          'totalElements': 1,
        },
      });

      final page = valueOf(
        await api.listRecipientsFiat(
          page: 2,
          pageSize: 10,
          recipientTypeFiat: ['SEPA_EUR'],
          isOwner: true,
          search: 'Ada',
        ),
      );

      expect(
        sent(),
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":'
        '{"paginator":{"page":2,"pageSize":10},"filters":'
        '{"recipientTypeFiat":["SEPA_EUR"],"isOwner":true,"search":"Ada"}}}',
      );
      expect(apiVersion(), '2.0.0');
      expect(page.totalElements, 1);
      expect(page.recipients.single.recipientId, 'r-1');
      expect(page.skippedElements, 0);
    });

    test('sends no filters when none is given', () async {
      answer({
        'result': {'totalElements': 0},
      });

      final page = valueOf(await api.listRecipientsFiat());

      expect(
        sent(),
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":'
        '{"paginator":{"page":1,"pageSize":50}}}',
      );
      expect(page.recipients, isEmpty);
      expect(page.totalElements, 0);
    });

    test('leaves out and counts the elements it cannot read', () async {
      answer({
        'result': {
          'elements': [
            _fiatRecipient,
            {..._fiatRecipient, 'recipientId': null},
            'not an object',
          ],
          'totalElements': 3,
        },
      });

      final page = valueOf(await api.listRecipientsFiat());

      expect(page.recipients.map((r) => r.recipientId), ['r-1']);
      expect(page.skippedElements, 2);
      expect(page.totalElements, 3);
    });

    test('a missing total is a format error', () async {
      answer({
        'result': {
          'elements': [_fiatRecipient],
        },
      });

      expect(
        await failedCall(api.listRecipientsFiat()),
        isA<BbxResponseFormatFailure>().having(
          (f) => f.reason,
          'reason',
          'invalid totalElements',
        ),
      );
    });

    test('a missing result is a format error', () async {
      answer({'result': null});

      expect(
        await failedCall(api.listRecipientsFiat()),
        isA<BbxResponseFormatFailure>(),
      );
    });

    test('an element list that is not a list is a format error', () async {
      answer({
        'result': {'elements': 'none', 'totalElements': 0},
      });

      expect(
        await failedCall(api.listRecipientsFiat()),
        isA<BbxResponseFormatFailure>(),
      );
    });
  });

  test('listRecipients sends the same params to listRecipients', () async {
    answer({
      'result': {'elements': <Object?>[], 'totalElements': 0},
    });

    valueOf(await api.listRecipients(isOwner: false));

    expect(
      sent(),
      '{"jsonrpc":"2.0","id":"0","method":"listRecipients","params":'
      '{"paginator":{"page":1,"pageSize":50},"filters":{"isOwner":false}}}',
    );
    expect(apiVersion(), '2.0.0');
  });

  group('checkSinpe', () {
    test('sends the phone number and reads the owner name', () async {
      answer({
        'result': {'ownerName': 'Ada'},
      });

      expect(valueOf(await api.checkSinpe(phoneNumber: '88888888')), 'Ada');
      expect(
        sent(),
        '{"jsonrpc":"2.0","id":"0","method":"checkSinpe","params":'
        '{"phoneNumber":"88888888"}}',
      );
      expect(apiVersion(), isNull);
    });

    test('a missing owner name is a format error', () async {
      answer({'result': <String, Object?>{}});

      expect(
        await failedCall(api.checkSinpe(phoneNumber: '88888888')),
        isA<BbxResponseFormatFailure>(),
      );
    });
  });

  group('listAplBillers', () {
    test('sends the search and reads the billers', () async {
      answer({
        'result': {
          'elements': [
            {'payeeCode': '0001', 'payeeName': 'Hydro'},
            {'payeeCode': 2, 'payeeName': 'Gas'},
          ],
        },
      });

      final search = valueOf(await api.listAplBillers(search: 'hyd'));

      expect(
        sent(),
        '{"jsonrpc":"2.0","id":"0","method":"listAplBillers","params":'
        '{"filters":{"search":"hyd"}}}',
      );
      expect(apiVersion(), isNull);
      expect(search.billers.single.payeeCode, '0001');
      expect(search.billers.single.payeeName, 'Hydro');
      expect(search.skippedElements, 1);
    });

    test('a missing element list is empty', () async {
      answer({'result': <String, Object?>{}});

      final search = valueOf(await api.listAplBillers(search: 'hyd'));

      expect(search.billers, isEmpty);
      expect(search.skippedElements, 0);
    });

    test('a missing result is a format error', () async {
      answer(<String, Object?>{});

      expect(
        await failedCall(api.listAplBillers(search: 'hyd')),
        isA<BbxResponseFormatFailure>(),
      );
    });
  });

  group('findVirtualIban', () {
    test('asks for one owned virtual account and reads it', () async {
      answer({
        'result': {
          'elements': [
            {
              'iban': 'FR76',
              'bicCode': 'FIRPFRP2',
              'bankAddress': 'Paris',
              'ibanCountry': 'FR',
            },
          ],
          'totalElements': 1,
        },
      });

      final iban =
          valueOf(await api.findVirtualIban()) ??
          fail('Expected a virtual IBAN');

      expect(
        sent(),
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":'
        '{"paginator":{"page":1,"pageSize":1},"filters":'
        '{"recipientTypeFiat":["SEPA_EUR_VIRTUAL_ACCOUNT"],"isOwner":true}}}',
      );
      expect(apiVersion(), '2.0.0');
      expect(iban.iban, 'FR76');
      expect(iban.bicCode, 'FIRPFRP2');
      expect(iban.bankAddress, 'Paris');
      expect(iban.ibanCountry, 'FR');
    });

    for (final result in [
      null,
      <String, Object?>{},
      {'elements': <Object?>[]},
    ]) {
      test('no virtual IBAN in $result is null', () async {
        answer({'result': result});

        expect(valueOf(await api.findVirtualIban()), isNull);
      });
    }
  });

  test('createVirtualIban creates an owned virtual account', () async {
    answer({
      'result': {'element': <String, Object?>{}},
    });

    final iban = valueOf(await api.createVirtualIban());

    expect(
      sent(),
      '{"jsonrpc":"2.0","id":"0","method":"createMyRecipient","params":'
      '{"element":{"recipientType":"FR_VIRTUAL_ACCOUNT","isOwner":true}}}',
    );
    expect(apiVersion(), isNull);
    expect(iban.iban, isNull);
  });

  test('activateSepaVirtualPayee sends the recipient with version 2', () async {
    answer({
      'result': {
        'element': {'recipientId': 'r-1', 'virtualPayeeStatus': 'PENDING'},
      },
    });

    final payee = valueOf(await api.activateSepaVirtualPayee('r-1'));

    expect(
      sent(),
      '{"jsonrpc":"2.0","id":"0","method":"activateSepaVirtualPayee",'
      '"params":{"recipientId":"r-1"}}',
    );
    expect(apiVersion(), '2.0.0');
    expect(payee.recipientId, 'r-1');
    expect(payee.virtualPayeeStatus, 'PENDING');
  });

  group('listSepaVirtualPayees', () {
    test('lists the SEPA recipients of a page with version 2', () async {
      answer({
        'result': {
          'elements': [
            {'recipientId': 'r-1'},
            {'recipientId': 'r-2', 'virtualPayeeStatus': 'ACTIVE'},
          ],
          'totalElements': 51,
        },
      });

      final page = valueOf(
        await api.listSepaVirtualPayees(page: 2, pageSize: 50),
      );

      expect(
        sent(),
        '{"jsonrpc":"2.0","id":"0","method":"listRecipientsFiat","params":'
        '{"paginator":{"page":2,"pageSize":50},"filters":'
        '{"recipientTypeFiat":["SEPA_EUR"]}}}',
      );
      expect(apiVersion(), '2.0.0');
      expect(page.totalElements, 51);
      expect(page.payees.map((p) => p.recipientId), ['r-1', 'r-2']);
      expect(page.payees.first.virtualPayeeStatus, isNull);
      expect(page.payees.last.virtualPayeeStatus, 'ACTIVE');
    });

    test('an element it cannot read fails the page', () async {
      answer({
        'result': {
          'elements': [
            {'virtualPayeeStatus': 'ACTIVE'},
          ],
          'totalElements': 1,
        },
      });

      expect(
        await failedCall(api.listSepaVirtualPayees(page: 1, pageSize: 50)),
        isA<BbxResponseFormatFailure>(),
      );
    });
  });

  group('errors', () {
    test('a JSON-RPC error keeps only its codes', () async {
      answer({
        'error': {
          'code': -32602,
          'message': 'invalid iban DE89',
          'data': {
            'apiError': {'code': 'ERR_RCP_PO404', 'message': 'DE89'},
          },
        },
      });

      expect(
        await failedCall(api.findVirtualIban()),
        isA<BbxRpcFailure>()
            .having((f) => f.code, 'code', -32602)
            .having((f) => f.apiCode, 'apiCode', 'ERR_RCP_PO404'),
      );
    });

    test('a status other than 200 is an HTTP failure', () async {
      answer({'result': null}, status: 204);

      expect(
        await failedCall(api.checkSinpe(phoneNumber: '1')),
        isA<BbxHttpFailure>().having((f) => f.status, 'status', 204),
      );
    });
  });
}
