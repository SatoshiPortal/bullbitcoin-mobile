import 'dart:io';

import 'package:bb_mobile/core/exchange/data/services/exchange_notification_service.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/create_log_attachment_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_support_chat_message_attachment_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_support_chat_messages_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/send_support_chat_message_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange_support_chat/presentation/exchange_support_chat_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _MockGetMessagesUsecase extends Mock
    implements GetSupportChatMessagesUsecase {}

class _MockSendMessageUsecase extends Mock
    implements SendSupportChatMessageUsecase {}

class _MockGetAttachmentUsecase extends Mock
    implements GetSupportChatMessageAttachmentUsecase {}

class _MockGetUserSummaryUsecase extends Mock
    implements GetExchangeUserSummaryUsecase {}

class _MockCreateLogAttachmentUsecase extends Mock
    implements CreateLogAttachmentUsecase {}

class _MockNotificationService extends Mock
    implements ExchangeNotificationService {}

/// Serves the test's temp directory as the platform temp directory.
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this._temporaryPath);

  final String _temporaryPath;

  @override
  Future<String?> getTemporaryPath() async => _temporaryPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockGetAttachmentUsecase getAttachmentUsecase;
  late ExchangeSupportChatCubit cubit;
  late Directory tempDir;

  setUp(() {
    getAttachmentUsecase = _MockGetAttachmentUsecase();
    final notificationService = _MockNotificationService();
    when(
      () => notificationService.messageStream,
    ).thenAnswer((_) => const Stream.empty());

    tempDir = Directory.systemTemp.createTempSync('support_chat_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);

    cubit = ExchangeSupportChatCubit(
      getMessagesUsecase: _MockGetMessagesUsecase(),
      sendMessageUsecase: _MockSendMessageUsecase(),
      getAttachmentUsecase: getAttachmentUsecase,
      getUserSummaryUsecase: _MockGetUserSummaryUsecase(),
      createLogAttachmentUsecase: _MockCreateLogAttachmentUsecase(),
      exchangeNotificationService: notificationService,
    );
  });

  tearDown(() async {
    await cubit.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('downloadAttachment — path traversal (audit)', () {
    test('audit reproducer: a server-supplied traversal fileName cannot write '
        'outside the temp directory', () async {
      // Before the fix, the fileName was concatenated verbatim into the
      // path, so this payload wrote attacker bytes over a sibling file.
      const payload = '../outside_the_sandbox.txt';
      when(() => getAttachmentUsecase.execute('att-1')).thenAnswer(
        (_) async => Ok(
          SupportChatMessageAttachment(
            attachmentId: 'att-1',
            fileName: payload,
            fileData: Uint8List.fromList('attacker bytes'.codeUnits),
          ),
        ),
      );

      await cubit.downloadAttachment('att-1');

      final escaped = File('${tempDir.parent.path}/outside_the_sandbox.txt');
      addTearDown(() {
        if (escaped.existsSync()) escaped.deleteSync();
      });
      expect(
        escaped.existsSync(),
        isFalse,
        reason: 'the download must never write outside the temp directory',
      );
      // The payload is reduced to its last segment and written inside.
      expect(
        File('${tempDir.path}/outside_the_sandbox.txt').existsSync(),
        isTrue,
      );
    });

    test(
      'a plain fileName is written as-is inside the temp directory',
      () async {
        when(() => getAttachmentUsecase.execute('att-2')).thenAnswer(
          (_) async => Ok(
            SupportChatMessageAttachment(
              attachmentId: 'att-2',
              fileName: 'receipt.pdf',
              fileData: Uint8List.fromList('%PDF'.codeUnits),
            ),
          ),
        );

        await cubit.downloadAttachment('att-2');

        expect(File('${tempDir.path}/receipt.pdf').existsSync(), isTrue);
      },
    );
  });
}
