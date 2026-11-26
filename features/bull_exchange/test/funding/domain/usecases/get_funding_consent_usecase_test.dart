import 'package:bull_exchange/src/funding/domain/usecases/get_funding_consent_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../funding_test_port.dart';

void main() {
  test('re-reads whether the consent is on the session account', () async {
    final funding = FundingTestPort()
      ..consentOnAccountAnswer = const ReadGot(true);
    final read = await GetFundingConsentUsecase(
      exchangeForTesting(funding: funding),
    ).execute(fundingSession);
    expect((read as ReadGot<bool>).value, isTrue);
    expect(funding.log, ['consentOnAccount a']);
  });
}
