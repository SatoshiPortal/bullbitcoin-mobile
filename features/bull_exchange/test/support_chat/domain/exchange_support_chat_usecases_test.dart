import 'package:bull_exchange/src/support_chat/domain/exchange_support_chat_failure.dart';
import 'package:bull_exchange/src/support_chat/domain/usecases/get_support_chat_message_attachment_usecase.dart';
import 'package:bull_exchange/src/support_chat/domain/usecases/get_support_chat_messages_usecase.dart';
import 'package:bull_exchange/src/support_chat/domain/usecases/send_support_chat_message_usecase.dart';
import 'package:preferences/preferences.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/setup.dart';
import 'package:exchange/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsRepository extends Mock implements Preferences {}

class _MockSettingsEntity extends Mock implements SettingsEntity {}

const _chatSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'chat',
);

void main() {
  group('support chat use-cases', () {
    late _MockSettingsRepository settingsRepository;

    setUp(() {
      settingsRepository = _MockSettingsRepository();

      final settings = _MockSettingsEntity();
      when(() => settings.environment).thenReturn(Environment.mainnet);
      when(() => settingsRepository.fetch())
          .thenAnswer((_) async => Ok(settings));
    });

    test(
      'GetSupportChatMessagesUsecase forwards the successful result',
      () async {
        final usecase = GetSupportChatMessagesUsecase(
          exchange: exchangeForTesting(
            access: fixedAccessForTesting(
              const ExchangeAccessSignedIn(_chatSession),
            ),
            chat: (
              getMessages: (_, {page, pageSize}) async {
                expect((page, pageSize), (1, 10));
                return const Ok([SupportChatMessage(messageId: '1')]);
              },
              sendMessage: (_, {required text, attachments}) async =>
                  fail('unexpected send'),
              getAttachment: (_, _) async => fail('unexpected download'),
              getUnreadCount: (_) async => fail('unexpected unread count'),
              markAllRead: (_) async => fail('unexpected mark read'),
            ),
          ),
        );

        final result = await usecase.execute(
          _chatSession,
          page: 1,
          pageSize: 10,
        );

        expect((result as Ok).value.single.messageId, '1');
      },
    );

    test(
      'use-case maps a settings read failure without sending a request',
      () async {
        final usecase = GetSupportChatMessagesUsecase(
          exchange: exchangeWithTransportForTesting(
            readSession: () => readLegacyExchangeSession(
              preferences: settingsRepository,
              readSession: () => null,
              readKey: ({required isTestnet}) async =>
                  fail('unexpected credential read'),
            ),
            openClient: (_, _) => fail('unexpected HTTP request'),
          ),
        );
        when(() => settingsRepository.fetch())
            .thenAnswer((_) async => const Err(PreferencesReadFailure()));

        final result = await usecase.execute(
          _chatSession,
          page: 1,
          pageSize: 10,
        );

        expect(
          (result as Err).failure,
          isA<ExchangeSupportChatUnexpectedFailure>(),
        );
      },
    );

    test(
      'SendSupportChatMessageUsecase maps an Exchange send failure',
      () async {
        final usecase = SendSupportChatMessageUsecase(
          exchange: exchangeForTesting(
            access: fixedAccessForTesting(
              const ExchangeAccessSignedIn(_chatSession),
            ),
            chat: (
              getMessages: (_, {page, pageSize}) async =>
                  fail('unexpected read'),
              sendMessage: (_, {required text, attachments}) async =>
                  const Err(ExchangeChatSendMessageFailure('raw')),
              getAttachment: (_, _) async => fail('unexpected download'),
              getUnreadCount: (_) async => fail('unexpected unread count'),
              markAllRead: (_) async => fail('unexpected mark read'),
            ),
          ),
        );

        final result = await usecase.execute(_chatSession, text: 'hi');

        expect((result as Err).failure, isA<SendMessageFailure>());
      },
    );

    test(
      'GetSupportChatMessageAttachmentUsecase maps a download failure',
      () async {
        final usecase = GetSupportChatMessageAttachmentUsecase(
          exchange: exchangeForTesting(
            access: fixedAccessForTesting(
              const ExchangeAccessSignedIn(_chatSession),
            ),
            chat: (
              getMessages: (_, {page, pageSize}) async =>
                  fail('unexpected read'),
              sendMessage: (_, {required text, attachments}) async =>
                  fail('unexpected send'),
              getAttachment: (_, _) async =>
                  const Err(ExchangeChatLoadAttachmentFailure('raw')),
              getUnreadCount: (_) async => fail('unexpected unread count'),
              markAllRead: (_) async => fail('unexpected mark read'),
            ),
          ),
        );

        final result = await usecase.execute(_chatSession, 'a1');

        expect((result as Err).failure, isA<LoadAttachmentFailure>());
      },
    );
  });
}
