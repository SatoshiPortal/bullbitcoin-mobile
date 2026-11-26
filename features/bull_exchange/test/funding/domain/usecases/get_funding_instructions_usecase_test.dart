import 'package:bull_exchange/src/funding/domain/fund_flow.dart';
import 'package:bull_exchange/src/funding/domain/usecases/get_funding_instructions_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/funding.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../funding_test_port.dart';

const _rows = FundingInstructionRows([
  InstructionRow(InstructionField.beneficiaryName, 'Bull Bitcoin'),
]);

/// The e-Transfer request the real machine fetches for a consented account.
FundingRequest _request() {
  final loaded = transitionFundFlow(
    fundFlowStart(fundingSession).state,
    FundAccountLoaded(1, ReadGot(fundingAccount())),
  );
  final picked = transitionFundFlow(
    loaded.state,
    const FundRailPicked(EmailETransferFundingRail()),
  );
  return picked.effects.whereType<FundFetchInstructions>().single.request;
}

void main() {
  test('fetches the request rail instructions for the session', () async {
    final funding = FundingTestPort()
      ..instructionsAnswer = const ReadGot(FundingInstructionsGot(_rows));
    final read = await GetFundingInstructionsUsecase(
      exchangeForTesting(funding: funding),
    ).execute(fundingSession, _request());
    expect(
      (read as ReadGot<FundingAnswer>).value,
      const FundingInstructionsGot(_rows),
    );
    expect(funding.log, [
      'instructions ${const EmailETransferFundingRail().name} a',
    ]);
  });
}
