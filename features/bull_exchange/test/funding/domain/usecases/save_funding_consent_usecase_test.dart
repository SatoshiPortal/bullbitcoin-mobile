import 'package:bull_exchange/src/funding/domain/usecases/save_funding_consent_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../funding_test_port.dart';

import 'package:primitives/primitives.dart';

void main() {
  test('records the consent for the session', () async {
    final funding = FundingTestPort()..consentAnswer = const Ok(null);
    final write = await SaveFundingConsentUsecase(
      exchangeForTesting(funding: funding),
    ).execute(fundingSession);
    expect(write, isA<Ok<void, ExchangeWriteFailure>>());
    expect(funding.log, ['consent a']);
  });

  test('an unknown outcome is kept, never read as saved', () async {
    final write = await SaveFundingConsentUsecase(
      exchangeForTesting(
        funding: FundingTestPort()
          ..consentAnswer = const Err(
            ExchangeWriteOutcomeUnknownFailure('lost'),
          ),
      ),
    ).execute(fundingSession);
    expect(
      write,
      isA<Err<void, ExchangeWriteFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeWriteOutcomeUnknownFailure>(),
      ),
    );
  });
}
