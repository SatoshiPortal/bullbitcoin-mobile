import 'package:bull_exchange/src/dca/domain/dca_state.dart';
import 'package:bull_exchange/src/dca/domain/dca_event.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';

import '../buy/buy_fixtures.dart';

import 'package:primitives/primitives.dart';

export '../buy/buy_fixtures.dart'
    show buyOtherSession, buySession, buySummaryWith;

const dcaWallets = DefaultWallets(
  bitcoin: DefaultWallet(
    walletType: BtcNetwork.bitcoin,
    address: 'bc1qdefault',
    isDefault: true,
  ),
);

DcaContext dcaContextWith({
  UserSummary? summary,
  DefaultWallets wallets = dcaWallets,
  List<UnknownWrite> openEntries = const [],
}) => DcaContext(
  summary: summary ?? buySummaryWith(),
  defaultWallets: wallets,
  openEntries: openEntries,
);

final dcaContext = dcaContextWith();

const dcaPayout = DcaPayout(BtcNetwork.bitcoin, 'bc1qdefault', isDefault: true);

DcaFlowNext applyDca(DcaFlowState state, List<DcaFlowEvent> events) {
  var next = DcaFlowNext.stay(state);
  for (final event in events) {
    next = next.state.next(event);
  }
  return next;
}

final dcaLoadingState = dcaFlowStart(buySession).state;
final dcaSetupState = applyDca(dcaLoadingState, [
  DcaContextLoaded(1, Ok(dcaContext)),
  const DcaAmountChanged(AmountRateArrived(ExchangeCatalog.cad, Ok(50000.0))),
]).state;
final dcaPayoutState = applyDca(dcaSetupState, const [
  DcaAmountChanged(AmountTyped('10')),
  DcaFrequencyPicked(DcaBuyFrequency.weekly),
  DcaContinuePressed(),
]).state;
final dcaReviewState = applyDca(dcaPayoutState, const [
  DcaPayoutChosen(dcaPayout),
]).state;
final dcaConfirmingState = applyDca(dcaReviewState, const [
  DcaConfirmPressed(),
]).state;
final dcaPlan = (dcaReviewState as DcaReview).plan;
final dcaDoneState = applyDca(dcaConfirmingState, [
  DcaConfirmChanged(ConfirmAnswered(1, Ok(dcaPlan))),
]).state;
