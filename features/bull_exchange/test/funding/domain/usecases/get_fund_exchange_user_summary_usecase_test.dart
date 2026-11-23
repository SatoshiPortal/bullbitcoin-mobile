import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:bull_exchange/src/funding/domain/usecases/get_fund_exchange_user_summary_usecase.dart';
import 'package:bull_exchange/src/funding/domain/fund_exchange_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../result_helpers.dart';

const _rawReason =
    'DioException [bad response]: {"error":{"message":"apikey=secret123"}}';

const _summary = UserSummary(
  userNumber: 1,
  groups: ['KYC_IDENTITY_VERIFIED'],
  profile: UserProfile(firstName: 'Sat', lastName: 'Oshi'),
  email: 'sat@example.com',
  balances: [],
  dca: UserDca(isActive: false),
  autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
);

void main() {
  Future<Result<UserSummary, FundExchangeFailure>> run(
    Result<UserSummary, ExchangeFailure> summary,
  ) => GetFundExchangeUserSummaryUsecase(
    exchange: exchangeForTesting(getUserSummary: (_) async => summary),
  ).execute();

  test('preserves a successful summary', () async {
    final result = await run(const Ok(_summary));

    expect(valueOf(result), _summary);
  });

  test('converts the foreign failure into a sanitized failure', () async {
    final result = await run(const Err(ExchangeUnexpectedFailure(_rawReason)));

    expect(result, isA<Err<UserSummary, FundExchangeFailure>>());
    final failure = failureOf(result);
    expect(failure, isA<FundExchangeUnexpectedFailure>());
    expect(
      failure.logMessage,
      isNot(contains('secret123')),
      reason: 'never retain the foreign diagnostic in the feature failure',
    );
  });

  test('an unavailable account is a typed funding failure', () async {
    expect(
      failureOf(await run(const Err(ExchangeAccountUnavailableFailure()))),
      isA<FundExchangeUnexpectedFailure>(),
    );
  });
}
