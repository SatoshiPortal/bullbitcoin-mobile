import 'package:bull_exchange/src/settings/domain/usecases/delete_exchange_account_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../../buy/buy_fixtures.dart';

Exchange _signedIn(List<String> sent, Result<void, ExchangeFailure> answer) =>
    exchangeForTesting(
      access: fixedAccessForTesting(const ExchangeAccessSignedIn(buySession)),
      chat: (
        getMessages: ({page, pageSize}) =>
            throw StateError('Unexpected chat history request'),
        sendMessage: ({required text, attachments}) async {
          sent.add(text);
          return answer;
        },
        getAttachment: (_) =>
            throw StateError('Unexpected chat attachment request'),
        getUnreadCount: (_) =>
            throw StateError('Unexpected chat unread count request'),
        markAllRead: (_) => throw StateError('Unexpected chat mark read'),
      ),
    );

void main() {
  test('signed out, nothing is sent', () async {
    final result = await DeleteExchangeAccountUsecase(
      exchangeForTesting(
        access: fixedAccessForTesting(const ExchangeAccessDisabled()),
      ),
    ).execute();
    expect((result as Err).failure, isA<ExchangeNotAuthenticatedFailure>());
  });

  test('a request support never got is a deletion failure', () async {
    final sent = <String>[];
    final result = await DeleteExchangeAccountUsecase(
      _signedIn(sent, const Err(ExchangeNetworkFailure())),
    ).execute();
    expect(sent, ['I want to delete my account']);
    expect(
      (result as Err).failure,
      isA<ExchangeAccountDeletionRequestFailure>(),
    );
  });
}
