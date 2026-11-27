import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';

import 'dca_state.dart';

@immutable
sealed class DcaFlowEffect {
  const DcaFlowEffect();
}

final class DcaLoadContext extends DcaFlowEffect {
  final int attempt;

  const DcaLoadContext(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is DcaLoadContext && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(DcaLoadContext, attempt);
}

final class DcaReloadForDetour extends DcaFlowEffect {
  const DcaReloadForDetour();

  @override
  bool operator ==(Object other) => other is DcaReloadForDetour;

  @override
  int get hashCode => (DcaReloadForDetour).hashCode;
}

final class DcaFetchRate extends DcaFlowEffect {
  final Market market;

  const DcaFetchRate(this.market);

  @override
  bool operator ==(Object other) =>
      other is DcaFetchRate && other.market == market;

  @override
  int get hashCode => Object.hash(DcaFetchRate, market);
}

final class DcaLoadDefaultWallets extends DcaFlowEffect {
  final int ticket;

  const DcaLoadDefaultWallets(this.ticket);

  @override
  bool operator ==(Object other) =>
      other is DcaLoadDefaultWallets && other.ticket == ticket;

  @override
  int get hashCode => Object.hash(DcaLoadDefaultWallets, ticket);
}

final class DcaConfirmEffect extends DcaFlowEffect {
  final ServerConfirmEffect<DcaPlan> effect;

  const DcaConfirmEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is DcaConfirmEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(DcaConfirmEffect, effect);
}

/// The recurring buy is active: turn the account's DCA preference on
/// (best-effort, as before).
final class DcaActivated extends DcaFlowEffect {
  const DcaActivated();

  @override
  bool operator ==(Object other) => other is DcaActivated;

  @override
  int get hashCode => (DcaActivated).hashCode;
}
