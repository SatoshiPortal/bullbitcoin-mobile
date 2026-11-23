import 'package:bb_mobile/features/exchange/domain/exchange_access.dart';
import 'package:bb_mobile/features/exchange/domain/repositories/exchange_access_repository.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_unread_support_message_count_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/mark_support_messages_read_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Access extends Mock implements ExchangeAccessRepository {}

const _signedIn = ExchangeAccessEnabled(ExchangeAccessSession.signedIn);
const _signedOut = ExchangeAccessEnabled(ExchangeAccessSession.signedOut);

void main() {
  late _Access access;
  late int counts;
  late int marks;
  late Future<Result<int, ExchangeFailure>> Function() onCount;
  late Future<Result<void, ExchangeFailure>> Function() onMark;

  Exchange exchange() => exchangeForTesting(
    chat: (
      getMessages: ({page, pageSize}) async => fail('unexpected chat read'),
      sendMessage: ({required text, attachments}) async =>
          fail('unexpected send'),
      getAttachment: (_) async => fail('unexpected attachment read'),
      getUnreadCount: () {
        counts++;
        return onCount();
      },
      markAllRead: () {
        marks++;
        return onMark();
      },
    ),
  );

  setUp(() {
    access = _Access();
    counts = 0;
    marks = 0;
    onCount = () async => const Ok(3);
    onMark = () async => const Ok(null);
    when(() => access.current).thenReturn(_signedIn);
    when(() => access.epoch).thenReturn(1);
  });

  group('GetUnreadSupportMessageCountUsecase', () {
    GetUnreadSupportMessageCountUsecase build() =>
        GetUnreadSupportMessageCountUsecase(
          exchange: exchange(),
          access: access,
        );

    test('returns the count of a signed-in session', () async {
      expect(await build().execute(), const Ok<int, ExchangeFailure>(3));
      expect(counts, 1);
    });

    test('does not ask the server when signed out', () async {
      when(() => access.current).thenReturn(_signedOut);

      expect(
        await build().execute(),
        isA<Err<int, ExchangeFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<ExchangeNotAuthenticatedFailure>(),
        ),
      );
      expect(counts, 0);
    });

    test('drops a count that arrives after the session changed', () async {
      onCount = () async {
        when(() => access.epoch).thenReturn(2);
        return const Ok(3);
      };

      expect(
        await build().execute(),
        isA<Err<int, ExchangeFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<ExchangeOperationStaleFailure>(),
        ),
      );
    });

    test('forwards a failed read', () async {
      onCount = () async => const Err(ExchangeChatLoadMessagesFailure('raw'));

      expect(
        await build().execute(),
        isA<Err<int, ExchangeFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<ExchangeChatLoadMessagesFailure>(),
        ),
      );
    });
  });

  group('MarkSupportMessagesReadUsecase', () {
    MarkSupportMessagesReadUsecase build() =>
        MarkSupportMessagesReadUsecase(exchange: exchange(), access: access);

    test('marks the messages of a signed-in session as read', () async {
      expect(await build().execute(), isA<Ok<void, ExchangeFailure>>());
      expect(marks, 1);
    });

    test('does not ask the server when signed out', () async {
      when(() => access.current).thenReturn(_signedOut);

      expect(
        await build().execute(),
        isA<Err<void, ExchangeFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<ExchangeNotAuthenticatedFailure>(),
        ),
      );
      expect(marks, 0);
    });
  });
}
