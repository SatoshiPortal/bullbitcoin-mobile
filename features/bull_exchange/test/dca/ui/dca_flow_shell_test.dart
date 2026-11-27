import 'package:bull_exchange/src/dca/domain/dca_state.dart';
import 'package:bull_exchange/src/dca/domain/dca_event.dart';
import 'package:bull_exchange/src/dca/ui/dca_flow_shell.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dca_fixtures.dart';

import 'package:primitives/primitives.dart';

Widget _field({
  required BtcNetwork type,
  required String value,
  required String label,
  required String hint,
  required bool enabled,
  required ValueChanged<String> onChanged,
  required ValueChanged<String?> onValidated,
}) => const SizedBox.shrink();

List<String> _keys(DcaFlowState state) => [
  for (final page in dcaPagesFor(state, payoutField: _field, onEvent: (_) {}))
    (page.key! as ValueKey<String>).value,
];

void main() {
  test('each state is its own page stack, earlier steps under it', () {
    expect(_keys(dcaLoadingState), ['dca-setup']);
    expect(_keys(dcaSetupState), ['dca-setup']);
    expect(_keys(dcaPayoutState), ['dca-setup', 'dca-payout']);
    expect(_keys(dcaReviewState), ['dca-setup', 'dca-payout', 'dca-review']);
    expect(_keys(dcaConfirmingState), [
      'dca-setup',
      'dca-payout',
      'dca-review',
    ]);
    expect(_keys(dcaDoneState), ['dca-end']);
    expect(_keys(const DcaSessionEnded()), ['dca-end']);
  });

  test('the funding detour is a page over the setup', () {
    final detour = applyDca(dcaSetupState, const [
      DcaAmountChanged(AmountTyped('500')),
      DcaFrequencyPicked(DcaBuyFrequency.daily),
      DcaContinuePressed(),
    ]).state;
    expect(_keys(detour), ['dca-setup', 'dca-detour']);
  });

  test('the KYC detour is a page over the setup', () {
    final low = dcaContextWith(summary: buySummaryWith(groups: const []));
    final detour = applyDca(dcaLoadingState, [
      DcaContextLoaded(1, Ok(low)),
      const DcaAmountChanged(
        AmountRateArrived(ExchangeCatalog.cad, Ok(50000.0)),
      ),
      const DcaAmountChanged(AmountTyped('10')),
      const DcaFrequencyPicked(DcaBuyFrequency.daily),
      const DcaContinuePressed(),
    ]).state;
    expect(_keys(detour), ['dca-setup', 'dca-detour']);
  });

  test('an unverified create is its own page, not the review', () {
    final unverified = applyDca(dcaConfirmingState, const [
      DcaConfirmChanged(
        ConfirmAnswered(
          1,
          GateAdmitted(Err(ExchangeWriteOutcomeUnknownFailure('lost'))),
        ),
      ),
      DcaConfirmChanged(
        ConfirmVerified(1, ConfirmCheckFailed(ReadProblemMalformed())),
      ),
    ]).state;
    expect(_keys(unverified).last, 'dca-confirm');
  });
}
