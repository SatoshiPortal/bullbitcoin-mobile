import 'dart:typed_data';

import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_support_chat_message_attachment_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_support_chat_messages_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/send_support_chat_message_usecase.dart';
import 'package:preferences/preferences.dart';
import 'package:bbx_api/bbx_api_testing.dart';
import 'package:dio/dio.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/setup.dart';
import 'package:exchange/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../features/exchange/data/bbx_api_test_http.dart';

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
    Exchange repository(
      HttpClientAdapter http, {
      String? key = anonymousTestApiKey,
    }) => exchangeWithTransportForTesting(
      readSession: () async =>
          Ok((environment: ExchangeEnvironment.mainnet, epoch: 0, apiKey: key)),
      openClient: (endpoint, readKey) => bbxForTesting(
        endpoint: endpoint.toString(),
        adapter: http,
        readActiveApiKey: readKey,
      ),
    );

    test('maps a missing API key to NotAuthenticatedFailure', () async {
      final result = await repository(
        FakeBbxHttp(),
        key: null,
      ).getSupportMessages();

      expect((result as Err).failure, isA<ExchangeNotAuthenticatedFailure>());
    });

    test('maps a transport throw to a sanitized LoadAttachmentFailure '
        'keeping the raw reason for logs only', () async {
      final result = await repository(
        _Throwing(Exception('network down at host=secret.internal')),
      ).getSupportAttachment('a1');

      final failure = (result as Err).failure;
      expect(failure, isA<ExchangeChatLoadAttachmentFailure>());
      expect(failure.logMessage, isNot(contains('secret.internal')));
    });

    test(
      'sendMessage with a missing API key returns NotAuthenticatedFailure',
      () async {
        final result = await repository(
          FakeBbxHttp(),
          key: null,
        ).sendSupportMessage(text: 'hi');

        expect((result as Err).failure, isA<ExchangeNotAuthenticatedFailure>());
      },
    );

    test('a key without a usable identity is an auth failure, not a load '
        'failure, and the thread is never requested', () async {
      final http = FakeBbxHttp(body: {'result': null});

      final result = await repository(http).getSupportMessages();

      expect((result as Err).failure, isA<ExchangeNotAuthenticatedFailure>());
      expect(http.requests.map((r) => r.path), ['/ak/api-users']);
    });
  });

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
            ),
          ),
        );

        final result = await usecase.execute('a1');

        expect((result as Err).failure, isA<LoadAttachmentFailure>());
      },
    );
  });
}
