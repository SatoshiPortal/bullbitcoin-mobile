import 'package:bull_exchange/src/support_chat/domain/usecases/get_unread_support_count_usecase.dart';
import 'package:bull_exchange/src/support_chat/domain/usecases/mark_support_messages_read_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

const _session = ExchangeSession(
  environment: ExchangeEnvironment.testnet,
  epoch: 3,
  sessionId: 'unread',
);
const _other = ExchangeSession(
  environment: ExchangeEnvironment.testnet,
  epoch: 4,
  sessionId: 'other',
);

Exchange _exchange(
  List<String> asked, {
  Result<int, ExchangeReadFailure> count = const Ok(2),
  Result<void, ExchangeWriteFailure> mark = const Ok(null),
}) => exchangeForTesting(
  access: fixedAccessForTesting(const ExchangeAccessSignedIn(_session)),
  chat: (
    getMessages: (_, {page, pageSize}) async => fail('unexpected read'),
    sendMessage: (_, {required text, attachments}) async =>
        fail('unexpected send'),
    getAttachment: (_, _) async => fail('unexpected download'),
    getUnreadCount: (session) async {
      asked.add('count ${session.sessionId}');
      return count;
    },
    markAllRead: (session) async {
      asked.add('mark ${session.sessionId}');
      return mark;
    },
  ),
);

void main() {
  group('GetUnreadSupportCountUsecase', () {
    test('reads the count for the session', () async {
      final asked = <String>[];
      final read = await GetUnreadSupportCountUsecase(_exchange(asked))
          .execute(_session);
      expect((read as Ok<int, ExchangeReadFailure>).value, 2);
      expect(asked, ['count unread']);
    });

    test('a failed read stays a failure, never a count', () async {
      final read = await GetUnreadSupportCountUsecase(
        _exchange([], count: const Err(ExchangeMalformedFailure('negative'))),
      ).execute(_session);
      expect(
        read,
        isA<Err<int, ExchangeReadFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeMalformedFailure>(),
        ),
      );
    });

    test('a read for another session is never sent', () async {
      final asked = <String>[];
      final read = await GetUnreadSupportCountUsecase(_exchange(asked))
          .execute(_other);
      expect(
        read,
        isA<Err<int, ExchangeReadFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeSessionRejectedFailure>(),
        ),
      );
      expect(asked, isEmpty);
    });
  });

  group('MarkSupportMessagesReadUsecase', () {
    test('marks the session user\'s messages read', () async {
      final asked = <String>[];
      final write = await MarkSupportMessagesReadUsecase(_exchange(asked))
          .execute(_session);
      expect(write, isA<Ok<void, ExchangeWriteFailure>>());
      expect(asked, ['mark unread']);
    });

    test('an unknown outcome stays unknown', () async {
      final write = await MarkSupportMessagesReadUsecase(
        _exchange(
          [],
          mark: const Err(ExchangeWriteOutcomeUnknownFailure('timeout')),
        ),
      ).execute(_session);
      expect(
        write,
        isA<Err<void, ExchangeWriteFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeWriteOutcomeUnknownFailure>(),
        ),
      );
    });

    test('a mark for another session is never sent', () async {
      final asked = <String>[];
      final write = await MarkSupportMessagesReadUsecase(_exchange(asked))
          .execute(_other);
      expect(
        write,
        isA<Err<void, ExchangeWriteFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<ExchangeWriteNotSentFailure>(),
        ),
      );
      expect(asked, isEmpty);
    });
  });
}
