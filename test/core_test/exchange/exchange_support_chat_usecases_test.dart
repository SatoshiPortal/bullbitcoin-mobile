import 'dart:typed_data';

import 'package:bb_mobile/features/exchange/data/bbx_api_support_chat_repository.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_support_chat_repository.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_support_chat_message_attachment_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_support_chat_messages_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/send_support_chat_message_usecase.dart';
import 'package:preferences/preferences.dart';
import 'package:bbx_api/bbx_api.dart' show Bbx;
import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../features/exchange/data/bbx_api_test_http.dart';

class _MockRepo extends Mock implements ExchangeSupportChatRepository {}

class _MockSettingsRepository extends Mock implements Preferences {}

class _MockSettingsEntity extends Mock implements SettingsEntity {}

class _Throwing implements HttpClientAdapter {
  final Object error;

  _Throwing(this.error);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw error;

  @override
  void close({bool force = false}) {}
}

void main() {
  group('BbxApiSupportChatRepository (the sanitization boundary)', () {
    BbxApiSupportChatRepository repository(Bbx api) =>
        BbxApiSupportChatRepository(
          users: api.users,
          commcenter: api.commcenter,
        );

    test('maps a missing API key to NotAuthenticatedFailure', () async {
      final result = await repository(
        FakeBbxHttp().client(readApiKey: () async => const Ok(null)),
      ).getMessages();

      expect((result as Err).failure, isA<NotAuthenticatedFailure>());
    });

    test('maps a transport throw to a sanitized LoadAttachmentFailure '
        'keeping the raw reason for logs only', () async {
      final api = bbxForTesting(
        endpoint: testBbxEndpoint,
        adapter: _Throwing(Exception('network down at host=secret.internal')),
        readActiveApiKey: bbxCredentialRead(null),
      );

      final result = await repository(api).getMessageAttachment('a1');

      final failure = (result as Err).failure;
      expect(failure, isA<LoadAttachmentFailure>());
      expect(failure.logMessage, isNot(contains('secret.internal')));
    });

    test(
      'sendMessage with a missing API key returns NotAuthenticatedFailure',
      () async {
        final result = await repository(
          FakeBbxHttp().client(readApiKey: () async => const Ok(null)),
        ).sendMessage(text: 'hi');

        expect((result as Err).failure, isA<NotAuthenticatedFailure>());
      },
    );

    test('a key without a usable identity is an auth failure, not a load '
        'failure, and the thread is never requested', () async {
      final http = FakeBbxHttp(body: {'result': null});

      final result = await repository(http.client()).getMessages();

      expect((result as Err).failure, isA<NotAuthenticatedFailure>());
      expect(http.requests.map((r) => r.path), ['/ak/api-users']);
    });
  });

  group('support chat use-cases (thin forwarders)', () {
    late _MockRepo mainnetRepo;
    late _MockRepo testnetRepo;
    late _MockSettingsRepository settingsRepository;

    setUp(() {
      mainnetRepo = _MockRepo();
      testnetRepo = _MockRepo();
      settingsRepository = _MockSettingsRepository();

      final settings = _MockSettingsEntity();
      when(() => settings.environment).thenReturn(Environment.mainnet);
      when(() => settingsRepository.fetch())
          .thenAnswer((_) async => Ok(settings));
    });

    test(
      'GetSupportChatMessagesUsecase forwards the repository Result',
      () async {
        final usecase = GetSupportChatMessagesUsecase(
          mainnetRepository: mainnetRepo,
          testnetRepository: testnetRepo,
          settingsRepository: settingsRepository,
        );
        when(
          () => mainnetRepo.getMessages(
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        ).thenAnswer(
          (_) async => const Ok([SupportChatMessage(messageId: '1')]),
        );

        final result = await usecase.execute(page: 1, pageSize: 10);

        expect((result as Ok).value.single.messageId, '1');
      },
    );

    test(
      'use-case maps a settings-fetch throw to a sanitized failure',
      () async {
        final usecase = GetSupportChatMessagesUsecase(
          mainnetRepository: mainnetRepo,
          testnetRepository: testnetRepo,
          settingsRepository: settingsRepository,
        );
        when(() => settingsRepository.fetch())
            .thenThrow(Exception('storage locked'));

        final result = await usecase.execute(page: 1, pageSize: 10);

        expect(
          (result as Err).failure,
          isA<ExchangeSupportChatUnexpectedFailure>(),
        );
      },
    );

    test(
      'SendSupportChatMessageUsecase forwards a repository failure',
      () async {
        final usecase = SendSupportChatMessageUsecase(
          mainnetRepository: mainnetRepo,
          testnetRepository: testnetRepo,
          settingsRepository: settingsRepository,
        );
        when(
          () => mainnetRepo.sendMessage(
            text: any(named: 'text'),
            attachments: any(named: 'attachments'),
          ),
        ).thenAnswer((_) async => const Err(SendMessageFailure('raw')));

        final result = await usecase.execute(text: 'hi');

        expect((result as Err).failure, isA<SendMessageFailure>());
      },
    );

    test(
      'GetSupportChatMessageAttachmentUsecase forwards the Result',
      () async {
        final usecase = GetSupportChatMessageAttachmentUsecase(
          mainnetRepository: mainnetRepo,
          testnetRepository: testnetRepo,
          settingsRepository: settingsRepository,
        );
        when(() => mainnetRepo.getMessageAttachment(any()))
            .thenAnswer((_) async => const Err(LoadAttachmentFailure('raw')));

        final result = await usecase.execute('a1');

        expect((result as Err).failure, isA<LoadAttachmentFailure>());
      },
    );
  });
}
