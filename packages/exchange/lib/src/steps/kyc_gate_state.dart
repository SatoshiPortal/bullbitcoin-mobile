import 'package:meta/meta.dart';

import '../domain/catalog/kyc_policy.dart';
import '../domain/catalog/market.dart';
import 'kyc_gate_effect.dart';
import 'kyc_gate_event.dart';
import 'step_next.dart';

/// Whether the account's KYC level lets it trade in [market] (and [amount]
/// in one transaction, when given).
bool kycAllows(Market market, Set<KycGroup> groups, {double? amount}) =>
    amount == null
    ? market.kyc.allowsTrading(groups)
    : !market.kyc.needsUpgrade(groups, amount);

/// The KYC gate's output: the KYC level check passed for [market]. Only the
/// gate makes one, so a step that takes it can't run without the check.
@immutable
final class KycCleared {
  final Market market;
  final double? amount;

  const KycCleared._(this.market, this.amount);

  @override
  bool operator ==(Object other) =>
      other is KycCleared && other.market == market && other.amount == amount;

  @override
  int get hashCode => Object.hash(KycCleared, market, amount);

  @override
  String toString() => 'KycCleared($market, $amount)';
}

/// The KYC level check of a flow without an amount step (composition
/// §4.10; AutoBuy). Amount entry runs the same check as its KYC detour. The
/// KYC web view opens over the flow, and returning re-checks the groups read
/// again.
@immutable
sealed class KycGateState {
  const KycGateState();

  KycGateNext next(KycGateEvent event) {
    final state = this;
    return switch ((state, event)) {
      (KycGateRequired(:final market, :final amount), KycGateOpenPressed()) =>
        StepNext(KycGateInKyc(market, amount: amount), [
          KycGateOpenKyc(market),
        ]),
      (KycGateRequired(), KycGateLeavePressed()) => const StepNext(
        KycGateLeft(),
      ),
      (KycGateRequired(), KycGateReturned()) => StepNext.stay(state),

      (
        KycGateInKyc(:final market, :final amount),
        KycGateReturned(:final groups),
      ) =>
        StepNext(_checked(market, groups, amount)),
      (KycGateInKyc(), KycGateOpenPressed() || KycGateLeavePressed()) =>
        StepNext.stay(state),

      (
        KycGatePassed() || KycGateLeft(),
        KycGateOpenPressed() || KycGateReturned() || KycGateLeavePressed(),
      ) =>
        StepNext.stay(state),
    };
  }
}

final class KycGateRequired extends KycGateState {
  final Market market;
  final double? amount;

  const KycGateRequired(this.market, {this.amount});

  @override
  bool operator ==(Object other) =>
      other is KycGateRequired &&
      other.market == market &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(KycGateRequired, market, amount);

  @override
  String toString() => 'KycGateRequired($market, $amount)';
}

/// The KYC web view is open over the flow.
final class KycGateInKyc extends KycGateState {
  final Market market;
  final double? amount;

  const KycGateInKyc(this.market, {this.amount});

  @override
  bool operator ==(Object other) =>
      other is KycGateInKyc && other.market == market && other.amount == amount;

  @override
  int get hashCode => Object.hash(KycGateInKyc, market, amount);

  @override
  String toString() => 'KycGateInKyc($market, $amount)';
}

/// Output.
final class KycGatePassed extends KycGateState {
  final KycCleared cleared;

  const KycGatePassed(this.cleared);

  @override
  bool operator ==(Object other) =>
      other is KycGatePassed && other.cleared == cleared;

  @override
  int get hashCode => Object.hash(KycGatePassed, cleared);

  @override
  String toString() => 'KycGatePassed($cleared)';
}

/// The user left the flow at the gate. Terminal.
final class KycGateLeft extends KycGateState {
  const KycGateLeft();
}

typedef KycGateNext = StepNext<KycGateState, KycGateEffect>;

KycGateState _checked(Market market, Set<KycGroup> groups, double? amount) =>
    kycAllows(market, groups, amount: amount)
    ? KycGatePassed(KycCleared._(market, amount))
    : KycGateRequired(market, amount: amount);

/// Passed at once when [groups] already allow the trade.
KycGateNext kycGateStart(
  Market market,
  Set<KycGroup> groups, {
  double? amount,
}) => StepNext(_checked(market, groups, amount));
