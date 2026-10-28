import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_support_chat_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_support_chat_message_attachment_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_support_chat_messages_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/send_support_chat_message_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements ExchangeSupportChatRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockSettingsEntity extends Mock implements SettingsEntity {}

void main() {
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
      when(() => settingsRepository.fetch()).thenAnswer((_) async => settings);
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
        when(
          () => settingsRepository.fetch(),
        ).thenThrow(Exception('storage locked'));

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
        when(
          () => mainnetRepo.getMessageAttachment(any()),
        ).thenAnswer((_) async => const Err(LoadAttachmentFailure('raw')));

        final result = await usecase.execute('a1');

        expect((result as Err).failure, isA<LoadAttachmentFailure>());
      },
    );
  });
}
