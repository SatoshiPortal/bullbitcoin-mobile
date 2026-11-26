import 'package:bull_exchange/src/support_chat/domain/usecases/send_support_chat_message_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

const _attachment = SupportChatMessageAttachment(
  attachmentId: 'a1',
  fileName: 'shot.png',
);

SendSupportChatMessageUsecase _usecase(List<String> sent) =>
    SendSupportChatMessageUsecase(
      exchange: exchangeForTesting(
        chat: (
          getMessages: ({page, pageSize}) async => fail('unexpected read'),
          sendMessage: ({required text, attachments}) async {
            sent.add(
              '$text ${attachments?.map((a) => a.attachmentId).toList()}',
            );
            return const Ok(null);
          },
          getAttachment: (_) async => fail('unexpected download'),
          getUnreadCount: (_) async => fail('unexpected unread count'),
          markAllRead: (_) async => fail('unexpected mark read'),
        ),
      ),
    );

void main() {
  test('a message without attachments is sent without the field', () async {
    final sent = <String>[];
    final result = await _usecase(sent).execute(text: 'hi', attachments: []);
    expect(result, isA<Ok<void, Failure>>());
    expect(sent, ['hi null']);
  });

  test('attachments are sent with the message', () async {
    final sent = <String>[];
    final result = await _usecase(sent)
        .execute(text: 'hi', attachments: const [_attachment]);
    expect(result, isA<Ok<void, Failure>>());
    expect(sent, ['hi [a1]']);
  });
}
