import 'package:bull_exchange/src/account/domain/usecases/get_user_summary_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../../buy/buy_fixtures.dart';

void main() {
  test('reads the summary of the session environment', () async {
    final asked = <ExchangeEnvironment?>[];
    const testnet = ExchangeSession(
      environment: ExchangeEnvironment.testnet,
      epoch: 3,
      sessionId: 't',
    );
    final read = await GetUserSummaryUsecase(
      exchangeForTesting(
        getUserSummary: (environment) async {
          asked.add(environment);
          return Ok(buySummary);
        },
      ),
    ).execute(testnet);
    expect((read as Ok<UserSummary, ExchangeReadFailure>).value, buySummary);
    expect(asked, [ExchangeEnvironment.testnet]);
  });

  test('a failed read is never a summary', () async {
    final read = await GetUserSummaryUsecase(
      exchangeForTesting(
        getUserSummary: (_) async => const Err(ExchangeNetworkFailure()),
      ),
    ).execute(buySession);
    expect(
      read,
      isA<Err<UserSummary, ExchangeReadFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeUnreachableFailure>(),
      ),
    );
  });
}
