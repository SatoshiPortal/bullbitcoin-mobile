import 'package:bull_exchange/src/funding/domain/usecases/save_funding_consent_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../funding_test_port.dart';

void main() {
  test('records the consent for the session', () async {
    final funding = FundingTestPort()..consentAnswer = const WriteDone(null);
    final write = await SaveFundingConsentUsecase(
      exchangeForTesting(funding: funding),
    ).execute(fundingSession);
    expect(write, isA<WriteDone<void>>());
    expect(funding.log, ['consent a']);
  });

  test('an unknown outcome is kept, never read as saved', () async {
    final write = await SaveFundingConsentUsecase(
      exchangeForTesting(
        funding: FundingTestPort()
          ..consentAnswer = const WriteOutcomeUnknown('lost'),
      ),
    ).execute(fundingSession);
    expect(write, isA<WriteOutcomeUnknown<void>>());
  });
}
