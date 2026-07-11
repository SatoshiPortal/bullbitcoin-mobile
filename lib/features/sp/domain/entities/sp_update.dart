/// Pure domain event describing a material change to the Silent Payments
/// wallet. Emitted by the repository and observed by other features (the
/// wallet feature) so SP never has to reach into another feature's bloc.
sealed class SpUpdate {
  const SpUpdate();
}

/// The SP balance changed (e.g. after a scan completed or a coin was
/// received/spent). Carries the new confirmed balance so observers can update
/// a cached balance cheaply, without reloading the live session.
class SpBalanceChanged extends SpUpdate {
  final BigInt confirmed;

  const SpBalanceChanged(this.confirmed);
}

/// The SP wallet's setup state changed (created or revoked). Observers must
/// re-evaluate from scratch (is-set-up + load), not just refresh a balance.
class SpSetupChanged extends SpUpdate {
  const SpSetupChanged();
}
