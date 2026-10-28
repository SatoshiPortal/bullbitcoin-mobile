import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/api_key_model.dart';
import 'package:bb_mobile/core/exchange/data/repository/bbx_api_exchange_support_chat_repository.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../core/exchange/fake_bbx_api.dart';

class _MockApiKeyDatasource extends Mock
    implements BullbitcoinApiKeyDatasource {}

class _FakeApiKey extends Fake implements ExchangeApiKeyModel {}

Map<String, dynamic> _summary() => {
  'userNumber': 42,
  'userId': 'user-1',
  'groups': <String>[],
  'profile': {'firstName': 'Test', 'lastName': 'User'},
  'email': 'test.user@example.com',
  'balances': <Object>[],
  'emailNotificationsEnabled': true,
  'twoFaEnabled': false,
  'dca': {'isActive': false},
  'autoBuy': {'isActive': false, 'addresses': <String, Object>{}},
  'kycDocumentStatus': {
    'secureFileUpload': 'NOT_UPLOADED',
    'documents': {
      'id': 'NOT_UPLOADED',
      'proofOfResidence': 'NOT_UPLOADED',
      'selfie': 'NOT_UPLOADED',
    },
  },
};

const _refusal = {
  'jsonrpc': '2.0',
  'id': '1',
  'error': {
    'code': -32602,
    'message': 'secret detail',
    'data': {
      'apiError': {'code': 'ERR_COM_ATH404', 'message': 'secret detail'},
    },
  },
};

void main() {
  late FakeBbxApi api;
  late _MockApiKeyDatasource apiKeys;
  late BbxApiExchangeSupportChatRepository repository;

  setUp(() {
    api = FakeBbxApi();
    apiKeys = _MockApiKeyDatasource();
    when(
      () => apiKeys.get(isTestnet: false),
    ).thenAnswer((_) async => _FakeApiKey());
    repository = BbxApiExchangeSupportChatRepository(
      api: api.datasource(),
      apiKeyDatasource: apiKeys,
      isTestnet: false,
    );
  });

  test('no stored key is not authenticated and sends nothing', () async {
    when(() => apiKeys.get(isTestnet: false)).thenAnswer((_) async => null);

    final result = await repository.getMessages();

    expect(
      (result as Err<List<SupportChatMessage>, ExchangeSupportChatFailure>)
          .failure,
      isA<NotAuthenticatedFailure>(),
    );
    expect(api.payloads, isEmpty);
  });

  test('a key the gateway refuses is not authenticated', () async {
    api.answers.add(
      const FakeHttpStatus(401, {
        'error': {'code': 401, 'status': 'Unauthorized'},
      }),
    );

    final result = await repository.getMessages();

    expect(
      (result as Err<List<SupportChatMessage>, ExchangeSupportChatFailure>)
          .failure,
      isA<NotAuthenticatedFailure>(),
    );
  });

  test('lists the messages of the user, newest first', () async {
    api.answers.addAll([rpcResult(_summary()), rpcPage([], 0)]);

    final result = await repository.getMessages(page: 2, pageSize: 5);

    expect(
      (result as Ok<List<SupportChatMessage>, ExchangeSupportChatFailure>)
          .value,
      isEmpty,
    );
    final params = api.payloads.last['params'] as Map;
    expect(params['sortBy'], {'id': 'createdAt', 'sort': 'desc'});
    expect(params['paginator'], {'page': 2, 'pageSize': 5});
  });

  test(
    'a refused attachment is a load failure without the server text',
    () async {
      api.answers.add(_refusal);

      final result = await repository.getMessageAttachment('a-1');

      final failure =
          (result
                  as Err<
                    SupportChatMessageAttachment,
                    ExchangeSupportChatFailure
                  >)
              .failure;
      expect(failure, isA<LoadAttachmentFailure>());
      expect(failure.logMessage, isNot(contains('secret detail')));
    },
  );
}
