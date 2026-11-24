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
            chat: (
              getMessages: ({page, pageSize}) async {
                expect((page, pageSize), (1, 10));
                return const Ok([SupportChatMessage(messageId: '1')]);
              },
              sendMessage: ({required text, attachments}) async =>
                  fail('unexpected send'),
              getAttachment: (_) async => fail('unexpected download'),
              getUnreadCount: () async => fail('unexpected unread count'),
              markAllRead: () async => fail('unexpected mark read'),
            ),
          ),
        );

        final result = await usecase.execute(page: 1, pageSize: 10);

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
              readEpoch: () => 0,
              readKey: ({required isTestnet}) async =>
                  fail('unexpected credential read'),
            ),
            openClient: (_, _) => fail('unexpected HTTP request'),
          ),
        );
        when(() => settingsRepository.fetch())
            .thenAnswer((_) async => const Err(PreferencesReadFailure()));

        final result = await usecase.execute(page: 1, pageSize: 10);

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
            chat: (
              getMessages: ({page, pageSize}) async => fail('unexpected read'),
              sendMessage: ({required text, attachments}) async =>
                  const Err(ExchangeChatSendMessageFailure('raw')),
              getAttachment: (_) async => fail('unexpected download'),
              getUnreadCount: () async => fail('unexpected unread count'),
              markAllRead: () async => fail('unexpected mark read'),
            ),
          ),
        );

        final result = await usecase.execute(text: 'hi');

        expect((result as Err).failure, isA<SendMessageFailure>());
      },
    );

    test(
      'GetSupportChatMessageAttachmentUsecase maps a download failure',
      () async {
        final usecase = GetSupportChatMessageAttachmentUsecase(
          exchange: exchangeForTesting(
            chat: (
              getMessages: ({page, pageSize}) async => fail('unexpected read'),
              sendMessage: ({required text, attachments}) async =>
                  fail('unexpected send'),
              getAttachment: (_) async =>
                  const Err(ExchangeChatLoadAttachmentFailure('raw')),
              getUnreadCount: () async => fail('unexpected unread count'),
              markAllRead: () async => fail('unexpected mark read'),
            ),
          ),
        );

        final result = await usecase.execute('a1');

        expect((result as Err).failure, isA<LoadAttachmentFailure>());
      },
    );
  });
}
