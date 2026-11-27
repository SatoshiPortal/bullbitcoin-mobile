import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:test/test.dart';

const _session = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 3,
  sessionId: 's',
);
const _other = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 4,
  sessionId: 't',
);

Exchange _exchange({
  required List<ExchangeSession> reads,
  required List<ExchangeSession> marks,
}) => exchangeForTesting(
  access: fixedAccessForTesting(const ExchangeAccessSignedIn(_session)),
  chat: (
    getMessages: (_, {page, pageSize}) => fail('unexpected history'),
    sendMessage: (_, {required text, attachments}) => fail('unexpected send'),
    getAttachment: (_, _) => fail('unexpected attachment'),
    getUnreadCount: (session) async {
      reads.add(session);
      return const ReadGot(2);
    },
    markAllRead: (session) async {
      marks.add(session);
      return const WriteDone(null);
    },
  ),
);

void main() {
  test('the count of the current session is read', () async {
    final reads = <ExchangeSession>[];
    final exchange = _exchange(reads: reads, marks: []);
    expect(
      await exchange.readUnreadSupportCount(_session),
      isA<ReadGot<int>>().having((r) => r.value, 'value', 2),
    );
    expect(reads, [_session]);
  });

  test('another session is never read or marked', () async {
    final reads = <ExchangeSession>[];
    final marks = <ExchangeSession>[];
    final exchange = _exchange(reads: reads, marks: marks);
    expect(
      await exchange.readUnreadSupportCount(_other),
      isA<ReadSessionRejected<int>>().having(
        (r) => r.why,
        'why',
        ExchangeSessionRejection.sessionChanged,
      ),
    );
    expect(
      await exchange.markSupportMessagesRead(_other),
      isA<WriteNotSent<void>>().having(
        (w) => w.reason,
        'reason',
        ExchangeNotSentReason.sessionChanged,
      ),
    );
    expect(reads, isEmpty);
    expect(marks, isEmpty);
  });

  test('the current session marks its messages read', () async {
    final marks = <ExchangeSession>[];
    final exchange = _exchange(reads: [], marks: marks);
    expect(
      await exchange.markSupportMessagesRead(_session),
      isA<WriteDone<void>>(),
    );
    expect(marks, [_session]);
  });

  test('a signed-out exchange never reads the count', () async {
    final exchange = exchangeForTesting(
      access: fixedAccessForTesting(
        const ExchangeAccessSignedOut(ExchangeEnvironment.mainnet),
      ),
    );
    expect(
      await exchange.readUnreadSupportCount(_session),
      isA<ReadSessionRejected<int>>(),
    );
  });
}
