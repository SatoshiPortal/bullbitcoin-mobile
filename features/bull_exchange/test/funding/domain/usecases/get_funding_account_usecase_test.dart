import 'package:bull_exchange/src/funding/domain/usecases/get_funding_account_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/funding.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../funding_test_port.dart';

void main() {
  test('reads the funding account of the session', () async {
    final funding = FundingTestPort()
      ..accountAnswer = ReadGot(fundingAccount());
    final read = await GetFundingAccountUsecase(
      exchangeForTesting(funding: funding),
    ).execute(fundingSession);
    expect((read as ReadGot<FundingAccount>).value.userNumber, 7);
    expect(funding.log, ['account a']);
  });

  test('a failed read stays a failure', () async {
    final read = await GetFundingAccountUsecase(
      exchangeForTesting(
        funding: FundingTestPort()
          ..accountAnswer = const ReadUnreachable('down', isNetwork: true),
      ),
    ).execute(fundingSession);
    expect(read, isA<ReadUnreachable<FundingAccount>>());
  });
}
