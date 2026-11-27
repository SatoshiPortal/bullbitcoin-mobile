import 'package:bull_exchange/src/funding/domain/usecases/get_funding_consent_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../funding_test_port.dart';

import 'package:primitives/primitives.dart';

void main() {
  test('re-reads whether the consent is on the session account', () async {
    final funding = FundingTestPort()..consentOnAccountAnswer = const Ok(true);
    final read = await GetFundingConsentUsecase(
      exchangeForTesting(funding: funding),
    ).execute(fundingSession);
    expect((read as Ok<bool, ExchangeReadFailure>).value, isTrue);
    expect(funding.log, ['consentOnAccount a']);
  });
}
