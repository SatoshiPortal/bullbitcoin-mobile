import 'package:bull_exchange/src/funding/domain/fund_flow.dart';
import 'package:bull_exchange/src/funding/domain/usecases/get_funding_instructions_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/funding.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../funding_test_port.dart';

import 'package:primitives/primitives.dart';

const _rows = FundingInstructionRows([
  InstructionRow(InstructionField.beneficiaryName, 'Bull Bitcoin'),
]);

/// The e-Transfer request the real machine fetches for a consented account.
FundingRequest _request() {
  final loaded = (fundFlowStart(
    fundingSession,
  ).state).next(FundAccountLoaded(1, Ok(fundingAccount())));
  final picked = loaded.state.next(
    const FundRailPicked(EmailETransferFundingRail()),
  );
  return picked.effects.whereType<FundFetchInstructions>().single.request;
}

void main() {
  test('fetches the request rail instructions for the session', () async {
    final funding = FundingTestPort()
      ..instructionsAnswer = const Ok(FundingInstructionsGot(_rows));
    final read = await GetFundingInstructionsUsecase(
      exchangeForTesting(funding: funding),
    ).execute(fundingSession, _request());
    expect(
      (read as Ok<FundingAnswer, ExchangeReadFailure>).value,
      const FundingInstructionsGot(_rows),
    );
    expect(funding.log, [
      'instructions ${const EmailETransferFundingRail().name} a',
    ]);
  });
}
