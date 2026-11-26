import 'package:bull_exchange/src/account/domain/usecases/get_account_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../../buy/buy_fixtures.dart';

void main() {
  const testnet = ExchangeSession(
    environment: ExchangeEnvironment.testnet,
    epoch: 3,
    sessionId: 't',
  );

  test('reads the account of the session environment', () async {
    final asked = <ExchangeEnvironment>[];
    final result = await GetAccountUsecase(
      exchangeForTesting(
        access: fixedAccessForTesting(const ExchangeAccessSignedIn(testnet)),
        getAccount: (environment) async {
          asked.add(environment);
          return Ok(buySummary);
        },
      ),
    ).execute(testnet);
    expect((result as Ok<UserSummary, ExchangeFailure>).value, buySummary);
    expect(asked, [ExchangeEnvironment.testnet]);
  });

  test('a session that is no longer current is refused unread', () async {
    final result = await GetAccountUsecase(
      exchangeForTesting(
        access: fixedAccessForTesting(const ExchangeAccessSignedIn(buySession)),
      ),
    ).execute(testnet);
    expect((result as Err).failure, isA<ExchangeOperationStaleFailure>());
  });

  test('a failed read is never an account', () async {
    final result = await GetAccountUsecase(
      exchangeForTesting(
        access: fixedAccessForTesting(const ExchangeAccessSignedIn(testnet)),
        getAccount: (_) async => const Err(ExchangeNetworkFailure()),
      ),
    ).execute(testnet);
    expect(result, isA<Err<UserSummary, ExchangeFailure>>());
  });
}
