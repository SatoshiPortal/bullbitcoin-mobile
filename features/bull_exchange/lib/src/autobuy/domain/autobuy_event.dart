import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'autobuy_state.dart';

typedef AutoBuyConfirmEvent = ServerConfirmEvent<AutoBuyTarget, bool>;

@immutable
sealed class AutoBuyFlowEvent {
  const AutoBuyFlowEvent();
}

final class AutoBuyContextLoaded extends AutoBuyFlowEvent {
  final int attempt;
  final Result<AutoBuyContext, ExchangeReadFailure> read;

  const AutoBuyContextLoaded(this.attempt, this.read);
}

final class AutoBuyRetryPressed extends AutoBuyFlowEvent {
  const AutoBuyRetryPressed();
}

final class AutoBuyBackPressed extends AutoBuyFlowEvent {
  const AutoBuyBackPressed();
}

final class AutoBuyDonePressed extends AutoBuyFlowEvent {
  const AutoBuyDonePressed();
}

final class AutoBuyGetStartedPressed extends AutoBuyFlowEvent {
  const AutoBuyGetStartedPressed();
}

/// Back from the KYC web view the KYC page opened.
final class AutoBuyKycReturned extends AutoBuyFlowEvent {
  const AutoBuyKycReturned();
}

/// The account read again after the KYC web view.
final class AutoBuyKycReloaded extends AutoBuyFlowEvent {
  final Result<AutoBuyContext, ExchangeReadFailure> read;

  const AutoBuyKycReloaded(this.read);
}

/// Continue under the editor, with the default wallets it shows saved.
final class AutoBuyWalletsContinued extends AutoBuyFlowEvent {
  final DefaultWallets wallets;

  const AutoBuyWalletsContinued(this.wallets);
}

final class AutoBuyActivatePressed extends AutoBuyFlowEvent {
  const AutoBuyActivatePressed();
}

final class AutoBuyConfirmChanged extends AutoBuyFlowEvent {
  final AutoBuyConfirmEvent event;

  const AutoBuyConfirmChanged(this.event);
}

final class AutoBuySessionChanged extends AutoBuyFlowEvent {
  final ExchangeSession? session;

  const AutoBuySessionChanged(this.session);
}
