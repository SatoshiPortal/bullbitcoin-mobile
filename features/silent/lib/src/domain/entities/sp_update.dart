import 'package:primitives/primitives.dart';

/// Pure domain event describing a material change to the Silent Payments
/// wallet. Emitted by the repository and observed by other features (the
/// wallet feature) so SP never has to reach into another feature's bloc.
sealed class SilentUpdate {
  const SilentUpdate();
}

/// The SP balance changed (e.g. after a scan completed or a coin was
/// received/spent). Carries the unified balance so observers can update a
/// cached balance cheaply, without reloading the live session.
class SilentBalanceChanged extends SilentUpdate {
  final Sats totalUnified;

  const SilentBalanceChanged(this.totalUnified);
}

/// The SP wallet's setup state changed (created or revoked). Observers must
/// re-evaluate from scratch (is-set-up + load), not just refresh a balance.
class SilentSetupChanged extends SilentUpdate {
  const SilentSetupChanged();
}

/// The chain tip became known, or moved. Observers that decide something from
/// the tip (the scan policy) must re-evaluate: at app start a sync tick usually
/// runs before the header store has reported any tip at all.
class SilentChainTipChanged extends SilentUpdate {
  final int tip;

  const SilentChainTipChanged(this.tip);
}
