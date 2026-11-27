import 'dart:io';

import 'package:bull_exchange/src/support_chat/domain/exchange_support_chat_failure.dart';
import 'package:bull_exchange/src/support_chat/domain/usecases/get_support_chat_message_attachment_usecase.dart';
import 'package:bull_exchange/src/support_chat/domain/usecases/open_support_chat_attachment_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockGetAttachmentUsecase extends Mock
    implements GetSupportChatMessageAttachmentUsecase {}

const _chatSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'chat',
);

void main() {
  late _MockGetAttachmentUsecase getAttachment;
  late Directory tempDir;
  late List<String> shared;
  late OpenSupportChatAttachmentUsecase open;

  setUp(() {
    getAttachment = _MockGetAttachmentUsecase();
    tempDir = Directory.systemTemp.createTempSync('support_chat_test');
    shared = [];
    open = OpenSupportChatAttachmentUsecase(
      getAttachment: getAttachment,
      temporaryDirectory: () async => tempDir,
      share: (path, _) async => shared.add(path),
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('path traversal (audit)', () {
    test('a server-supplied traversal fileName cannot write outside the '
        'temp directory', () async {
      const payload = '../outside_the_sandbox.txt';
      when(() => getAttachment.execute(_chatSession, 'att-1')).thenAnswer(
        (_) async => Ok(
          SupportChatMessageAttachment(
            attachmentId: 'att-1',
            fileName: payload,
            fileData: Uint8List.fromList('attacker bytes'.codeUnits),
          ),
        ),
      );

      expect(
        await open.execute(_chatSession, 'att-1'),
        isA<Ok<void, ExchangeSupportChatFailure>>(),
      );

      final escaped = File('${tempDir.parent.path}/outside_the_sandbox.txt');
      addTearDown(() {
        if (escaped.existsSync()) escaped.deleteSync();
      });
      expect(escaped.existsSync(), isFalse);
      expect(
        File('${tempDir.path}/outside_the_sandbox.txt').existsSync(),
        isTrue,
      );
      expect(shared, ['${tempDir.path}/outside_the_sandbox.txt']);
    });

    test(
      'a plain fileName is written as-is inside the temp directory',
      () async {
        when(() => getAttachment.execute(_chatSession, 'att-2')).thenAnswer(
          (_) async => Ok(
            SupportChatMessageAttachment(
              attachmentId: 'att-2',
              fileName: 'receipt.pdf',
              fileData: Uint8List.fromList('%PDF'.codeUnits),
            ),
          ),
        );

        expect(
          await open.execute(_chatSession, 'att-2'),
          isA<Ok<void, ExchangeSupportChatFailure>>(),
        );

        expect(File('${tempDir.path}/receipt.pdf').existsSync(), isTrue);
      },
    );
  });

  test('an attachment without data is a fetch failure', () async {
    when(() => getAttachment.execute(_chatSession, 'att-3')).thenAnswer(
      (_) async =>
          const Ok(SupportChatMessageAttachment(attachmentId: 'att-3')),
    );
    final result = await open.execute(_chatSession, 'att-3');
    expect(
      (result as Err<void, ExchangeSupportChatFailure>).failure,
      isA<FetchFileDataFailure>(),
    );
  });

  test('a failing share sheet is a load failure, not a crash', () async {
    open = OpenSupportChatAttachmentUsecase(
      getAttachment: getAttachment,
      temporaryDirectory: () async => tempDir,
      share: (_, _) async => throw const FileSystemException('no popover'),
    );
    when(() => getAttachment.execute(_chatSession, 'att-4')).thenAnswer(
      (_) async => Ok(
        SupportChatMessageAttachment(
          attachmentId: 'att-4',
          fileName: 'a.txt',
          fileData: Uint8List.fromList('a'.codeUnits),
        ),
      ),
    );
    final result = await open.execute(_chatSession, 'att-4');
    expect(
      (result as Err<void, ExchangeSupportChatFailure>).failure,
      isA<LoadAttachmentFailure>(),
    );
  });
}
