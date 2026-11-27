import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'dca_state.dart';

typedef DcaConfirmEvent = ServerConfirmEvent<DcaPlan, DcaPlan>;

@immutable
sealed class DcaFlowEvent {
  const DcaFlowEvent();
}

final class DcaContextLoaded extends DcaFlowEvent {
  final int attempt;
  final Result<DcaContext, ExchangeReadFailure> read;

  const DcaContextLoaded(this.attempt, this.read);
}

final class DcaRetryPressed extends DcaFlowEvent {
  const DcaRetryPressed();
}

final class DcaAmountChanged extends DcaFlowEvent {
  final AmountEntryEvent event;

  const DcaAmountChanged(this.event);
}

final class DcaFrequencyPicked extends DcaFlowEvent {
  final DcaBuyFrequency frequency;

  const DcaFrequencyPicked(this.frequency);
}

final class DcaContinuePressed extends DcaFlowEvent {
  const DcaContinuePressed();
}

/// Back from funding the account.
final class DcaFundingReturned extends DcaFlowEvent {
  const DcaFundingReturned();
}

/// Back from the KYC web view.
final class DcaKycReturned extends DcaFlowEvent {
  const DcaKycReturned();
}

final class DcaDetourLoaded extends DcaFlowEvent {
  final Result<DcaContext, ExchangeReadFailure> read;

  const DcaDetourLoaded(this.read);
}

final class DcaPayoutChosen extends DcaFlowEvent {
  final DcaPayout payout;

  const DcaPayoutChosen(this.payout);
}

/// Back from the default wallets editor.
final class DcaDefaultWalletsReturned extends DcaFlowEvent {
  const DcaDefaultWalletsReturned();
}

final class DcaDefaultWalletsLoaded extends DcaFlowEvent {
  final int ticket;
  final Result<DefaultWallets, ExchangeReadFailure> read;

  const DcaDefaultWalletsLoaded(this.ticket, this.read);
}

final class DcaConfirmPressed extends DcaFlowEvent {
  const DcaConfirmPressed();
}

final class DcaConfirmChanged extends DcaFlowEvent {
  final DcaConfirmEvent event;

  const DcaConfirmChanged(this.event);
}

final class DcaBackPressed extends DcaFlowEvent {
  const DcaBackPressed();
}

final class DcaDonePressed extends DcaFlowEvent {
  const DcaDonePressed();
}

final class DcaSessionChanged extends DcaFlowEvent {
  final ExchangeSession? session;

  const DcaSessionChanged(this.session);
}
