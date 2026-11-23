import 'package:exchange/exchange.dart';

import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/features/recipients/data/bbx_api_recipients_repository.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_details_input.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_type.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/recipients_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../exchange/data/bbx_api_test_http.dart';
import 'bbx_api_recipients_repository_legacy.dart';

const _iban = 'DE89370400440532013000';

/// A refusal shaped like a real one: the JSON-RPC error quotes the rejected
/// payload and a server stack trace.
const _errorBody = {
  'error': {
    'code': -32602,
    'message': 'invalid iban $_iban',
    'data': {
      'stack': 'at RecipientService.create (/srv/api/recipients.js:214)',
    },
  },
};

Map<String, dynamic> _wire(
  String id,
  String type,
  Map<String, Object?> details,
) => {
  'recipientId': id,
  'userId': 'user-1',
  'userNbr': 1,
  'isArchived': false,
  'createdAt': '2026-10-01T00:00:00.000Z',
  'updatedAt': '2026-10-02T00:00:00.000Z',
  'recipientTypeFiat': type,
  'label': 'label-$id',
  'isOwner': true,
  'isDefault': false,
  ...details,
};

/// One recipient of every type, as the API returns it.
final _everyType = [
  _wire('interac', 'INTERAC_EMAIL_CAD', {
    'email': 'a@example.com',
    'name': 'Ada',
    'securityQuestion': 'Q?',
    'securityAnswer': 'answer',
  }),
  _wire('bill', 'BILL_PAYMENT_CAD', {
    'payeeName': 'Hydro',
    'payeeCode': '0001',
    'payeeAccountNumber': '123',
  }),
  _wire('bank', 'BANK_TRANSFER_CAD', {
    'institutionNumber': '001',
    'transitNumber': '12345',
    'accountNumber': '1234567',
    'name': 'Ada',
    'defaultComment': 'rent',
  }),
  _wire('sepa', 'SEPA_EUR', {
    'iban': _iban,
    'isCorporate': false,
    'firstname': 'Ada',
    'lastname': 'Lovelace',
    'virtualPayeeStatus': 'ACTIVE',
  }),
  _wire('sepa-corp', 'SEPA_EUR', {
    'iban': _iban,
    'isCorporate': true,
    'corporateName': 'ACME',
  }),
  _wire('clabe', 'SPEI_CLABE_MXN', {
    'clabe': '002010077777777771',
    'name': 'Ada',
  }),
  _wire('sms', 'SPEI_SMS_MXN', {
    'institutionCode': '40002',
    'phone': '5512345678',
    'name': 'Ada',
  }),
  _wire('card', 'SPEI_CARD_MXN', {
    'institutionCode': '40002',
    'debitcard': '4111111111111111',
    'name': 'Ada',
  }),
  _wire('sinpe-usd', 'SINPE_IBAN_USD', {
    'iban': 'CR05015202001026284066',
    'ownerName': 'Ada',
  }),
  _wire('sinpe-crc', 'SINPE_IBAN_CRC', {'iban': 'CR05015202001026284066'}),
  _wire('movil', 'SINPE_MOVIL_CRC', {
    'phoneNumber': '88888888',
    'ownerName': 'Ada',
  }),
  _wire('ars', 'BANK_TRANSFER_ARS', {
    'claveUniform': '0000003100010000000001',
    'name': 'Ada',
  }),
  _wire('pse', 'PSE_COLOMBIA_COP', {
    'name': 'Ada',
    'accountType': 'SAVINGS',
    'bankAccount': '123',
    'bankCode': '1007',
    'bankName': 'Bancolombia',
    'documentId': '99',
    'documentType': 'CC',
  }),
  _wire('nequi', 'NEQUI_COLOMBIA_COP', {
    'bankAccount': '3001234567',
    'documentId': '99',
    'documentType': 'CC',
    'name': 'Ada',
  }),
];

/// The details of one recipient of every type, as the app builds them.
final _newRecipients = <RecipientDetails>[
  for (final type in RecipientType.values)
    RecipientDetailsInput(
      recipientType: type,
      label: 'label-${type.name}',
      isOwner: type != RecipientType.billPaymentCad,
      isDefault: type == RecipientType.interacEmailCad,
      email: 'a@example.com',
      name: 'Ada',
      securityQuestion: type == RecipientType.interacEmailCad ? 'Q?' : null,
      securityAnswer: type == RecipientType.interacEmailCad ? 'answer' : null,
      payeeName: 'Hydro',
      payeeCode: '0001',
      payeeAccountNumber: '123',
      institutionNumber: '001',
      transitNumber: '12345',
      accountNumber: '1234567',
      defaultComment: 'rent',
      iban: type == RecipientType.sepaEur ? _iban : 'CR05015202001026284066',
      isCorporate: type == RecipientType.confidentialSepaEur ? true : null,
      firstname: 'Ada',
      lastname: 'Lovelace',
      corporateName: type == RecipientType.confidentialSepaEur ? 'ACME' : null,
      clabe: '002010077777777771',
      institutionCode: '40002',
      phone: '5512345678',
      debitcard: '4111111111111111',
      ownerName: type == RecipientType.sinpeIbanCrc ? null : 'Ada',
      phoneNumber: '88888888',
      claveUniform: '0000003100010000000001',
      bankCode: '1007',
      accountType: 'SAVINGS',
      bankAccount: '123',
      bankName: 'Bancolombia',
      documentId: '99',
      documentType: 'CC',
    ).toDomain(),
];

BbxApiRecipientsRepository _repository(FakeBbxHttp http) =>
    BbxApiRecipientsRepository(api: http.client());

/// The path, the JSON text and the `x-api-version` header of each request.
List<(String, String, Object?)> _sent(FakeBbxHttp http) => [
  for (final r in http.requests)
    (r.path, jsonEncode(r.data), r.headers['x-api-version']),
];

/// Runs [call] on the repository; returns what the old repository sent for
/// the same answer, recorded before it was removed, and what it sends.
Future<(List<Object?>, List<(String, String, Object?)>)> _bothSend(
  String id,
  Object? body,
  Future<void> Function(RecipientsRepository repository) call,
) async {
  final http = FakeBbxHttp(body: body);
  await call(_repository(http));
  final old = oldRepository[id];
  if (old is! List<Object?>) {
    fail('Expected legacy recipient requests for $id');
  }
  return (old, _sent(http));
}

/// The flat wire details the old repository's model gave for [d].
Map<String, Object?> _detailsJson(RecipientDetails d) {
  final fields = switch (d) {
    InteracEmailCadDetails() => {
      'email': d.email,
      'name': d.name,
      'securityQuestion': d.securityQuestion,
      'securityAnswer': d.securityAnswer,
    },
    BillPaymentCadDetails() => {
      'payeeName': d.payeeName,
      'payeeCode': d.payeeCode,
      'payeeAccountNumber': d.payeeAccountNumber,
    },
    BankTransferCadDetails() => {
      'institutionNumber': d.institutionNumber,
      'transitNumber': d.transitNumber,
      'accountNumber': d.accountNumber,
      'name': d.name,
      'defaultComment': d.defaultComment,
    },
    SepaEurDetails() => {
      'iban': d.iban,
      'isCorporate': d.isCorporate,
      'firstname': d.firstname,
      'lastname': d.lastname,
      'corporateName': d.corporateName,
    },
    SpeiClabeMxnDetails() => {'clabe': d.clabe, 'name': d.name},
    SpeiSmsMxnDetails() => {
      'institutionCode': d.institutionCode,
      'phone': d.phone,
      'name': d.name,
    },
    SpeiCardMxnDetails() => {
      'institutionCode': d.institutionCode,
      'debitcard': d.debitcard,
      'name': d.name,
    },
    SinpeIbanUsdDetails() => {'iban': d.iban, 'ownerName': d.ownerName},
    SinpeIbanCrcDetails() => {'iban': d.iban, 'ownerName': d.ownerName},
    SinpeMovilCrcDetails() => {
      'phoneNumber': d.phoneNumber,
      'ownerName': d.ownerName,
    },
    BankAccountArgentinaDetails() => {
      'claveUniform': d.claveUniform,
      'name': d.name,
    },
    PseColombiaDetails() => {
      'accountType': d.accountType,
      'bankAccount': d.bankAccount,
      'bankCode': d.bankCode,
      'bankName': d.bankName,
      'documentId': d.documentId,
      'documentType': d.documentType,
      'name': d.name,
    },
    NequiColombiaDetails() => {
      'bankAccount': d.phoneNumber,
      'documentId': d.documentId,
      'documentType': d.documentType,
      'name': d.name,
    },
  };
  return {
    'recipientTypeFiat': d.type.value,
    'label': ?d.label,
    'isOwner': ?d.isOwner,
    'isDefault': d.isDefault,
    'isArchived': false,
    for (final MapEntry(:key, :value) in fields.entries) key: ?value,
  };
}

/// Everything the app reads from a recipient.
Map<String, Object?> _canonical(Recipient r) => {
  'recipientId': r.recipientId,
  'userId': r.userId,
  'userNbr': r.userNbr,
  'isArchived': r.isArchived,
  'createdAt': r.createdAt.toIso8601String(),
  'updatedAt': r.updatedAt.toIso8601String(),
  'type': r.type.name,
  'details': _detailsJson(r.details),
  if (r.details case final SepaEurDetails sepa)
    'virtualPayeeStatus': sepa.virtualPayeeStatus.name,
};

T _valueOf<T>(Result<T, RecipientsFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected an Ok, got ${failure.runtimeType}'),
};

RecipientsFailure _failureOf<T>(Result<T, RecipientsFailure> result) =>
    switch (result) {
      Ok() => fail('expected an Err, got Ok'),
      Err(:final failure) => failure,
    };

void main() {
  group('the requests are the ones the old repository sent, as recorded', () {
    for (final details in _newRecipients) {
      test('saveRecipient of ${details.type.name}', () async {
        final (old, sent) = await _bothSend('save ${details.type.name}', {
          'result': {'element': _everyType.first},
        }, (r) => r.saveRecipient(details, isTestnet: true));

        expect(sent, old);
        expect(sent.single.$3, '2.0.0');
      });
    }

    test('saveRecipient sends the flat details of the type', () async {
      final http = FakeBbxHttp(
        body: {
          'result': {'element': _everyType.first},
        },
      );

      await _repository(http).saveRecipient(
        const RecipientDetailsInput(
          recipientType: RecipientType.nequiColombia,
          isOwner: true,
          phoneNumber: '3001234567',
          documentId: '99',
          documentType: 'CC',
          name: 'Ada',
        ).toDomain(),
        isTestnet: false,
      );

      expect(_sent(http), [
        (
          '/ak/api-recipients',
          '{"jsonrpc":"2.0","id":"0","method":"createRecipientFiat","params":'
              '{"element":{"recipientTypeFiat":"NEQUI_COLOMBIA_COP",'
              '"isOwner":true,"isDefault":false,"isArchived":false,'
              '"name":"Ada","bankAccount":"3001234567","documentId":"99",'
              '"documentType":"CC"}}}',
          '2.0.0',
        ),
      ]);
    });

    final listCalls = <String, Future<void> Function(RecipientsRepository)>{
      'default': (r) => r.listRecipients(isTestnet: true),
      'all recipients': (r) =>
          r.listRecipients(isTestnet: true, fiatOnly: false),
      'every filter': (r) => r.listRecipients(
        isTestnet: true,
        page: 3,
        pageSize: 20,
        recipientTypes: [
          RecipientType.sepaEur,
          RecipientType.confidentialSepaEur,
          RecipientType.interacEmailCad,
        ],
        isOwner: false,
        search: 'Ada',
      ),
      'empty filters': (r) => r.listRecipients(
        isTestnet: true,
        recipientTypes: const [],
        search: '',
      ),
    };
    for (final MapEntry(key: name, value: call) in listCalls.entries) {
      test('listRecipients with $name', () async {
        final (old, sent) = await _bothSend('list $name', {
          'result': {'elements': <Object?>[], 'totalElements': 0},
        }, call);

        expect(sent, old);
      });
    }

    test('updateInteracSecurityDetails', () async {
      for (final (question, answer) in [('Q?', 'A'), (null, null)]) {
        final (old, sent) = await _bothSend(
          'interac $question',
          {'result': <String, Object?>{}},
          (r) => r.updateInteracSecurityDetails(
            recipientId: 'r-1',
            email: 'a@example.com',
            securityQuestion: question,
            securityAnswer: answer,
            isTestnet: true,
          ),
        );

        expect(sent, old);
        expect(sent.single.$3, '2.0.0');
      }
    });

    test('checkSinpe', () async {
      final (old, sent) = await _bothSend('checkSinpe', {
        'result': {'ownerName': 'Ada'},
      }, (r) => r.checkSinpe(phoneNumber: '88888888', isTestnet: true));

      expect(sent, old);
      expect(sent.single.$3, isNull);
    });

    test('listCadBillers', () async {
      final (old, sent) = await _bothSend('listCadBillers', {
        'result': {'elements': <Object?>[]},
      }, (r) => r.listCadBillers(searchTerm: 'hy', isTestnet: true));

      expect(sent, old);
      expect(sent.single.$3, isNull);
    });
  });

  group('responses are mapped like the old repository did, as recorded', () {
    Future<List<Map<String, Object?>>> listWith(
      RecipientsRepository repository,
      List<RecipientType>? types,
    ) async => _valueOf(
      await repository.listRecipients(isTestnet: true, recipientTypes: types),
    ).recipients.map(_canonical).toList();

    final unreadable = [
      _wire('unknown-type', 'GIFT_CARD_XYZ', {}),
      _wire('empty-iban', 'SEPA_EUR', {'iban': ' ', 'isCorporate': true}),
      _wire('no-name', 'NEQUI_COLOMBIA_COP', {
        'bankAccount': '1',
        'documentId': '9',
        'documentType': 'CC',
      }),
      {
        ..._wire('bad-date', 'SINPE_MOVIL_CRC', {'phoneNumber': '8'}),
        'createdAt': 'yesterday',
      },
      {
        ..._wire('no-user', 'SINPE_MOVIL_CRC', {'phoneNumber': '8'}),
        'userId': null,
      },
      {
        ..._wire('bad-flag', 'SINPE_MOVIL_CRC', {'phoneNumber': '8'}),
        'isOwner': 'yes',
      },
      'not an object',
    ];

    for (final types in <List<RecipientType>?>[
      null,
      [RecipientType.sepaEur],
      [RecipientType.confidentialSepaEur],
    ]) {
      test('a list of every type, filtered by $types', () async {
        final body = {
          'result': {
            'elements': [..._everyType, ...unreadable],
            'totalElements': 99,
          },
        };
        final mapped = await listWith(
          _repository(FakeBbxHttp(body: body)),
          types,
        );

        expect(mapped, oldRepository['mapped $types']);
        expect(mapped, isNotEmpty);
      });
    }

    test('every type is read, and unreadable ones are skipped', () async {
      final result = _valueOf(
        await _repository(
          FakeBbxHttp(
            body: {
              'result': {
                'elements': [..._everyType, ...unreadable],
                'totalElements': 99,
              },
            },
          ),
        ).listRecipients(isTestnet: true),
      );

      expect(result.totalRecipients, 99);
      expect(
        result.recipients.map((r) => r.recipientId),
        _everyType.map((e) => e['recipientId']),
      );
      expect(
        result.recipients.map((r) => r.type),
        RecipientType.values
            .where((t) => t != RecipientType.confidentialSepaEur)
            .expand((t) => t == RecipientType.sepaEur ? [t, t] : [t]),
      );
    });

    test('a missing element list is empty', () async {
      final result = _valueOf(
        await _repository(
          FakeBbxHttp(
            body: {
              'result': {'totalElements': 4},
            },
          ),
        ).listRecipients(isTestnet: true),
      );

      expect(result.recipients, isEmpty);
      expect(result.totalRecipients, 4);
    });

    test('a saved recipient is the one returned', () async {
      for (final element in _everyType) {
        final body = {
          'result': {'element': element},
        };
        final details = _newRecipients.first;
        final saved = await _repository(FakeBbxHttp(body: body))
            .saveRecipient(details, isTestnet: true);

        expect(
          _canonical(_valueOf(saved)),
          oldRepository['saved ${element['recipientId']}'],
        );
      }
    });

    test('a saved recipient the app cannot read is a save failure', () async {
      final result = await _repository(
        FakeBbxHttp(
          body: {
            'result': {'element': unreadable.first},
          },
        ),
      ).saveRecipient(_newRecipients.first, isTestnet: true);

      expect(_failureOf(result), isA<RecipientsSaveFailure>());
    });

    test('checkSinpe returns the owner name', () async {
      final result = await _repository(
        FakeBbxHttp(
          body: {
            'result': {'ownerName': 'Ada'},
          },
        ),
      ).checkSinpe(phoneNumber: '88888888', isTestnet: true);

      expect(_valueOf(result), 'Ada');
    });

    test('CAD billers are read, and unusable ones are skipped', () async {
      final result = await _repository(
        FakeBbxHttp(
          body: {
            'result': {
              'elements': [
                {'payeeCode': '0001', 'payeeName': 'Hydro'},
                {'payeeCode': '', 'payeeName': 'Empty'},
                {'payeeCode': 2, 'payeeName': 'Number'},
                {'payeeCode': '0003', 'payeeName': 'Gas'},
              ],
            },
          },
        ),
      ).listCadBillers(searchTerm: 'hy', isTestnet: true);

      expect(_valueOf(result).map((b) => (b.payeeCode, b.payeeName)), [
        ('0001', 'Hydro'),
        ('0003', 'Gas'),
      ]);
    });

    test('no CAD biller element list is no biller', () async {
      final result = await _repository(
        FakeBbxHttp(body: {'result': <String, Object?>{}}),
      ).listCadBillers(searchTerm: 'hy', isTestnet: true);

      expect(_valueOf(result), isEmpty);
    });
  });

  group('SEPA rows in a recipient list', () {
    Map<String, dynamic> sepa(
      String id, {
      bool isOwner = true,
      bool isCorporate = false,
      String? virtualPayeeStatus,
    }) => {
      'recipientId': id,
      'userId': 'user-1',
      'userNbr': 1,
      'isArchived': false,
      'createdAt': '2026-10-01T00:00:00.000Z',
      'updatedAt': '2026-10-01T00:00:00.000Z',
      'recipientTypeFiat': 'SEPA_EUR',
      'isOwner': isOwner,
      'iban': 'FR7630006000011234567890189',
      'isCorporate': isCorporate,
      if (isCorporate) 'corporateName': 'Bull Bitcoin',
      if (!isCorporate) 'firstname': 'Satoshi',
      if (!isCorporate) 'lastname': 'Nakamoto',
      'virtualPayeeStatus': ?virtualPayeeStatus,
    };

    FakeBbxHttp listOf(List<Map<String, dynamic>> elements) => FakeBbxHttp(
      body: {
        'result': {'elements': elements, 'totalElements': elements.length},
      },
    );

    Future<List<(String, RecipientType)>> rows(
      FakeBbxHttp http,
      List<RecipientType>? recipientTypes,
    ) async {
      final value = _valueOf(
        await _repository(http)
            .listRecipients(isTestnet: true, recipientTypes: recipientTypes),
      );
      return [for (final r in value.recipients) (r.recipientId, r.type)];
    }

    test('both SEPA types are requested from the api as one type', () async {
      final http = listOf([]);

      await rows(http, [
        RecipientType.sepaEur,
        RecipientType.confidentialSepaEur,
      ]);

      final request = http.requests.single.data as Map<String, dynamic>;
      final params = request['params'] as Map<String, dynamic>;
      expect(params['filters'], {
        'recipientTypeFiat': ['SEPA_EUR'],
      });
    });

    test('a list of all types shows each SEPA recipient once', () async {
      final elements = [sepa('a', virtualPayeeStatus: 'ACTIVE'), sepa('b')];

      expect(await rows(listOf(elements), null), [
        ('a', RecipientType.sepaEur),
        ('b', RecipientType.sepaEur),
      ]);
      expect(
        await rows(listOf(elements), [
          RecipientType.sepaEur,
          RecipientType.confidentialSepaEur,
        ]),
        [('a', RecipientType.sepaEur), ('b', RecipientType.sepaEur)],
      );
    });

    test('a regular SEPA list shows the regular rows', () async {
      expect(
        await rows(listOf([sepa('a', virtualPayeeStatus: 'ACTIVE')]), [
          RecipientType.sepaEur,
        ]),
        [('a', RecipientType.sepaEur)],
      );
    });

    test('a Confidential SEPA list shows the confidential rows', () async {
      final http = listOf([
        sepa('active', virtualPayeeStatus: 'ACTIVE'),
        sepa('pending', virtualPayeeStatus: 'CREATED'),
        sepa('eligible'),
      ]);

      expect(await rows(http, [RecipientType.confidentialSepaEur]), [
        ('active', RecipientType.confidentialSepaEur),
        ('pending', RecipientType.confidentialSepaEur),
        ('eligible', RecipientType.confidentialSepaEur),
      ]);
    });

    test(
      'a Confidential SEPA list leaves out recipients that cannot be activated',
      () async {
        final http = listOf([
          sepa('corporate', isCorporate: true),
          sepa('other', isOwner: false),
        ]);

        expect(await rows(http, [RecipientType.confidentialSepaEur]), isEmpty);
      },
    );

    test('a Confidential SEPA list keeps an existing virtual payee', () async {
      final http = listOf([
        sepa('corporate', isCorporate: true, virtualPayeeStatus: 'ACTIVE'),
      ]);

      expect(await rows(http, [RecipientType.confidentialSepaEur]), [
        ('corporate', RecipientType.confidentialSepaEur),
      ]);
    });
  });

  group('failures', () {
    final operations =
        <
          String,
          Future<Result<Object?, RecipientsFailure>> Function(
            RecipientsRepository,
          )
        >{
          'saveRecipient': (r) =>
              r.saveRecipient(_newRecipients.first, isTestnet: true),
          'updateInteracSecurityDetails': (r) => r.updateInteracSecurityDetails(
            recipientId: 'r-1',
            email: 'a@example.com',
            securityQuestion: 'Q?',
            securityAnswer: 'A',
            isTestnet: true,
          ),
          'listRecipients': (r) => r.listRecipients(isTestnet: true),
          'checkSinpe': (r) =>
              r.checkSinpe(phoneNumber: '88888888', isTestnet: true),
          'listCadBillers': (r) =>
              r.listCadBillers(searchTerm: 'hy', isTestnet: true),
        };
    final apiFailures = <String, Matcher>{
      'saveRecipient': isA<RecipientsSaveFailure>(),
      'updateInteracSecurityDetails': isA<RecipientsUnexpectedFailure>(),
      'listRecipients': isA<RecipientsLoadFailure>(),
      'checkSinpe': isA<RecipientsSinpeLookupFailure>(),
      'listCadBillers': isA<RecipientsCadBillerSearchFailure>(),
    };

    for (final MapEntry(key: name, value: call) in operations.entries) {
      final apiFailure =
          apiFailures[name] ??
          fail('Missing recipient failure matcher for $name');

      test('$name: a JSON-RPC error is the operation failure', () async {
        final failure = _failureOf(
          await call(_repository(FakeBbxHttp(body: _errorBody))),
        );

        expect(failure, apiFailure);
        expect(failure.logMessage, isNull);
      });

      test('$name: a status other than 200 is the operation failure', () async {
        expect(
          _failureOf(await call(_repository(FakeBbxHttp(status: 204)))),
          apiFailure,
        );
      });

      test(
        '$name: a response without a result is the operation failure',
        () async {
          final result = await call(
            _repository(FakeBbxHttp(body: {'result': null})),
          );

          // The old update did not read its result either.
          if (name == 'updateInteracSecurityDetails') {
            expect(result, isA<Ok<Object?, RecipientsFailure>>());
          } else {
            expect(_failureOf(result), apiFailure);
          }
        },
      );

      test('$name: a timeout is a network failure', () async {
        expect(
          _failureOf(
            await call(
              _repository(
                FakeBbxHttp(error: DioExceptionType.connectionTimeout),
              ),
            ),
          ),
          isA<RecipientsNetworkFailure>(),
        );
      });

      test('$name: a bad response is the operation failure', () async {
        expect(
          _failureOf(
            await call(
              _repository(FakeBbxHttp(error: DioExceptionType.badResponse)),
            ),
          ),
          apiFailure,
        );
      });

      test('$name: no credential is not authenticated', () async {
        final http = FakeBbxHttp(body: {'result': <String, Object?>{}});
        final repository = BbxApiRecipientsRepository(
          api: http.client(readApiKey: () async => const Ok(null)),
        );

        expect(
          _failureOf(await call(repository)),
          isA<RecipientsNotAuthenticatedFailure>(),
        );
        expect(http.requests, isEmpty);
      });

      test(
        '$name: an unreadable credential is the operation failure',
        () async {
          final http = FakeBbxHttp(body: {'result': <String, Object?>{}});
          final repository = BbxApiRecipientsRepository(
            api: http.client(
              readApiKey: () async =>
                  const Err(ExchangeCredentialReadFailure()),
            ),
          );

          final failure = _failureOf(await call(repository));

          expect(failure, apiFailure);
          expect(failure.logMessage, 'Exchange credential unavailable');
        },
      );
    }

    test('a list without its total is a load failure', () async {
      final result = await _repository(
        FakeBbxHttp(
          body: {
            'result': {'elements': _everyType},
          },
        ),
      ).listRecipients(isTestnet: true);

      expect(_failureOf(result), isA<RecipientsLoadFailure>());
    });

    test('refusal logs omit the payload', () async {
      final directory = await Directory.systemTemp.createTemp('recipient-log-');
      await initializeLogging(directory: directory, background: true);
      final repository = _repository(FakeBbxHttp(body: _errorBody));

      for (final call in operations.values) {
        await call(repository);
      }
      await log.flush();

      final contents = await log.logsFile.readAsString();
      expect(contents, contains('JSON-RPC error code -32602'));
      expect(contents, isNot(contains(_iban)));
      expect(contents, isNot(contains('RecipientService.create')));
    });
  });
}
